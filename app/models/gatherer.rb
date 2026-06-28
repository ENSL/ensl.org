# frozen_string_literal: true

# == Schema Information
#
# Table name: gatherers
#
#  id         :integer          not null, primary key
#  status     :integer          default(0), not null
#  team       :integer
#  votes      :integer          default(0), not null
#  created_at :datetime
#  updated_at :datetime
#  gather_id  :integer
#  user_id    :integer
#
# Indexes
#
#  index_gatherers_on_gather_id                 (gather_id)
#  index_gatherers_on_updated_at_and_gather_id  (updated_at,gather_id)
#  index_gatherers_on_user_id                   (user_id)
#

class Gatherer < ApplicationRecord
  IDLE_TIME = 600
  EJECT_VOTES = 4

  STATE_ACTIVE = 0
  STATE_AWAY = 1
  STATE_LEAVING = 2
  STATUS_BY_KEY = {
    'leaving' => STATE_LEAVING,
    'away' => STATE_AWAY,
    'active' => STATE_ACTIVE
  }.freeze

  UpdateForActorResult = Struct.new(:authorized, :updated, :errors, keyword_init: true)

  include Extra

  # attr_protected :id
  attr_accessor :confirm, :username
  attr_accessor :skip_callbacks

  scope :team, ->(team) { where(team: team) }
  scope :of_user, ->(user) { where(user_id: user.id) }
  scope :lobby, -> { where(team: nil) }
  scope :best,
        lambda { |gather|
          {
            select: 'u.id, u.username, ' \
                    '(COUNT(*) / (SELECT COUNT(*) FROM gatherers g3 WHERE g3.user_id = u.id)) AS skill, g4.id',
            from: 'gathers g1',
            joins: "LEFT JOIN gatherers g2 ON g1.captain1_id = g2.id OR g1.captain2_id = g2.id
  LEFT JOIN users u ON g2.user_id = u.id
  LEFT JOIN gatherers g4 ON u.id = g4.user_id AND g4.gather_id = #{gather.id}",
            group: 'u.id',
            having: 'g4.id IS NOT NULL',
            order: 'skill DESC',
            limit: 15
          }
        }
  scope :with_kpd, lambda {
    select('gatherers.*, SUM(kills)/SUM(deaths) as kpd, COUNT(rounders.id) as rounds')
      .joins('LEFT JOIN rounders ON rounders.user_id = gatherers.user_id')
      .group('rounders.user_id')
      .order('kpd DESC')
  }
  scope :lobby_team, lambda { |team|
    where('gatherers.team IS NULL OR gatherers.team = ?', team)
      .order('gatherers.team')
  }
  scope :most_voted, -> { order('votes DESC, created_at DESC') }
  scope :not_user, ->(user) { where('user_id != ?', user.id) }
  scope :eject_order, -> { order('votes ASC') }
  scope :ordered, lambda {
    joins('LEFT JOIN gathers ON captain1_id = gatherers.id OR captain2_id = gatherers.id')
      .order('captain1_id, captain2_id, gatherers.id')
  }
  scope :for_pick_list, lambda { |team|
    if team.nil?
      ordered.team(team)
    else
      pick_order_nulls_last = Arel::Nodes::Case.new
                                               .when(arel_table[:pick_order].eq(nil)).then(1)
                                               .else(0)

      team(team)
        .order(pick_order_nulls_last.asc)
        .order(arel_table[:pick_order].asc)
        .order(arel_table[:updated_at].asc)
        .order(arel_table[:id].asc)
    end
  }
  scope :idle, lambda {
    joins('LEFT JOIN users ON users.id = gatherers.user_id')
      .where('lastvisit < ?', 30.minutes.ago.utc)
  }

  belongs_to :user, optional: true
  belongs_to :gather, optional: true
  has_many :real_votes, class_name: 'Vote', as: :votable, dependent: :destroy

  validates :user_id, uniqueness: { scope: :gather_id }
  validates :team, inclusion: { in: 1..2, allow_nil: true }
  validates :pick_order, numericality: { only_integer: true, greater_than: 0, allow_nil: true }
  validates :confirm, acceptance: true, unless: proc { |gatherer| gatherer.user.gatherers.count >= 5 }
  validate :validate_username

  after_create :start_gather, if: proc { |gatherer| gatherer.gather.gatherers.count == Gather::FULL }
  after_create :notify_gatherers, if: proc { |gatherer| gatherer.gather.gatherers.count == Gather::NOTIFY }
  before_save :assign_pick_order_on_pick
  after_update :change_turn, unless: proc { |gatherer| gatherer.skip_callbacks == true }
  after_destroy :cleanup_votes

  delegate :to_s, to: :user

  def validate_username
    return unless username

    if (u = User.where(username: username).first)
      self.user = u
    else
      errors.add(:username, t(:gatherer_wrong_username))
    end
  end

  def start_gather
    # Use a DB lock to avoid race conditions when multiple gatherers are created concurrently
    gather.with_lock do
      if gather.gatherers.count >= Gather::FULL && gather.status != Gather::STATE_VOTING
        gather.update!(status: Gather::STATE_VOTING)
      end
    end
  end

  def notify_gatherers
    # Ensure only one notifier runs when hitting the NOTIFY threshold
    gather.with_lock do
      return unless gather.gatherers.count >= Gather::NOTIFY
    end

    Profile.where(notify_gather: 1).includes(:user).find_each do |p|
      Notifications.gather p.user, gather if p.user&.profile&.notify_pms
    end
  end

  def change_turn
    return unless (respond_to?(:saved_change_to_team?) ? saved_change_to_team? : team_changed?) && !team.nil?

    # Perform all related state updates under a DB lock to avoid races
    gather.with_lock do
      new_turn = (team == 1 ? 2 : 1)
      if (team == 2) && [2, 4].include?(gather.gatherers.team(2).count.to_i)
        new_turn = 2
      elsif (team == 1) && [3, 5].include?(gather.gatherers.team(1).count.to_i)
        new_turn = 1
      end
      gather.update!(turn: new_turn)

      if gather.gatherers.lobby.count == 1
        g = gather.gatherers.lobby.first
        g.update!(team: (team == 1 ? 2 : 1))
      end

      gather.update!(status: Gather::STATE_FINISHED) if gather.gatherers.lobby.count.zero?
    end
  end

  def assign_pick_order_on_pick
    return unless should_assign_pick_order?
    return unless gather

    gather.with_lock do
      self.pick_order = gather.gatherers.where.not(id: id).maximum(:pick_order).to_i + 1
    end
  end

  def should_assign_pick_order?
    return false if pick_order.present? || team.nil?

    if respond_to?(:will_save_change_to_team?)
      will_save_change_to_team? && team_change_to_be_saved&.first.nil?
    else
      team_changed? && team_was.nil?
    end
  end

  def cleanup_votes
    gather.map_votes.where(user_id: user_id).destroy_all
    gather.server_votes.where(user_id: user_id).destroy_all
    gather.gatherer_votes.where(user_id: user_id).destroy_all
  end

  def votes_needed?
    5
  end

  def captain?
    gather.captain1 == self or gather.captain2 == self
  end

  def turn?
    (gather.captain1 == self and gather.turn == 1) or (gather.captain2 == self and gather.turn == 2)
  end

  def self.status_from_key(status_key)
    STATUS_BY_KEY[status_key.to_s]
  end

  def update_for_actor(raw_params, actor)
    gatherer_params = self.class.params(raw_params, actor)
    unless can_update?(actor, gatherer_params)
      return UpdateForActorResult.new(authorized: false, updated: false, errors: errors)
    end

    updated = update(gatherer_params)
    Gathers::Broadcaster.call(gather) if updated
    UpdateForActorResult.new(authorized: true, updated: updated, errors: errors)
  end

  def update_status_from_key(status_key)
    status_value = self.class.status_from_key(status_key)
    return false unless status_value

    update!(status: status_value)
    Gathers::Broadcaster.call(gather)
    true
  end

  # When a player who had flagged themselves as leaving loads the gather again we
  # treat them as active. Keeping this on the model avoids the controller poking
  # at status constants directly.
  def reactivate_if_returning!
    return unless status == STATE_LEAVING

    update!(status: STATE_ACTIVE)
  end

  def can_create?(cuser, _params = {})
    # and check_params(params, [:user_id, :gather_id])
    cuser \
      and user == cuser \
      and !cuser.banned?(Ban::TYPE_GATHER) \
      and gather.status == Gather::STATE_RUNNING \
      and gather.gatherers.count < Gather::FULL \
      and !gather.gatherers.of_user(cuser).first
  end

  def can_update?(cuser, params = {})
    return false unless cuser

    if params.keys.include? 'username'
      return true if cuser.admin? || cuser.gather_moderator?

      return false

    end
    captain_turn = ((gather.captain1&.user == cuser) && (gather.turn == 1)) ||
                   ((gather.captain2&.user == cuser) && (gather.turn == 2))
    return false unless team.nil? && captain_turn
    return false if (gather.turn == 1) && (gather.gatherers.team(1).count == 2) && (gather.gatherers.team(2).count < 3)
    return false if (gather.turn == 2) && (gather.gatherers.team(1).count < 4) && (gather.gatherers.team(2).count == 3)
    return false if (gather.turn == 1) && (gather.gatherers.team(1).count == 4) && (gather.gatherers.team(2).count < 5)
    return false if (gather.turn == 2) && (gather.gatherers.team(1).count < 6) && (gather.gatherers.team(2).count == 5)
    return false if (gather.turn == 1) && (gather.gatherers.team(1).count == 6)

    true
  end

  def can_destroy?(cuser)
    cuser and ((user == cuser or cuser.admin? or cuser.gather_moderator?) and gather.status == Gather::STATE_RUNNING)
  end

  def self.params(params, _cuser)
    params.require(:gatherer).permit(:status, :username, :user_id, :gather_id, :team, :votes, :confirm)
  end
end
