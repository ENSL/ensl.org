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

  attr_accessor :confirm, :skip_callbacks, :username

  scope :team, ->(team) { where(team: team) }
  scope :of_user, ->(user) { where(user_id: user.id) }
  scope :lobby, -> { where(team: nil) }
  scope :most_voted, -> { order('votes DESC, created_at DESC') }
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

  before_save :assign_pick_order_on_pick
  after_create :update_gather_after_join
  after_update :advance_gather_after_pick, unless: proc { |gatherer| gatherer.skip_callbacks == true }
  after_destroy :remove_gather_votes

  delegate :to_s, to: :user

  class << self
    def status_from_key(status_key)
      STATUS_BY_KEY[status_key.to_s]
    end

    def params(params, _cuser)
      params.require(:gatherer).permit(:status, :username, :user_id, :gather_id, :team, :votes, :confirm)
    end
  end

  def validate_username
    return unless username

    if (u = User.where(username: username).first)
      self.user = u
    else
      errors.add(:username, t(:gatherer_wrong_username))
    end
  end

  def captain?
    gather.captain1 == self || gather.captain2 == self
  end

  def turn?
    (gather.captain1 == self && gather.turn == 1) || (gather.captain2 == self && gather.turn == 2)
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

  def reactivate_if_returning!
    return unless status == STATE_LEAVING

    update!(status: STATE_ACTIVE)
  end

  def can_create?(cuser, _params = {})
    joining_actor?(cuser) && gather.open_for_join? && gather.gatherers.of_user(cuser).none?
  end

  def can_update?(cuser, params = {})
    return false unless cuser
    return cuser.admin? || cuser.gather_moderator? if params.key?('username')
    return false unless team.nil? && captains_turn?(cuser)

    gather.picking_slot_available?
  end

  def can_destroy?(cuser)
    return false unless cuser && gather.status == Gather::STATE_RUNNING

    user == cuser || privileged?(cuser)
  end

  private

  def update_gather_after_join
    member_count = gather.gatherers.count
    gather.notify_interested_users_if_threshold_reached! if member_count == Gather::NOTIFY
    gather.start_voting_if_full! if member_count == Gather::FULL
  end

  def advance_gather_after_pick
    return unless saved_change_to_team? && team.present?

    gather.advance_picking_after_pick!
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

  def remove_gather_votes
    gather.map_votes.where(user_id: user_id).destroy_all
    gather.server_votes.where(user_id: user_id).destroy_all
    gather.gatherer_votes.where(user_id: user_id).destroy_all
  end

  def joining_actor?(cuser)
    return false unless cuser

    user == cuser && !cuser.banned?(Ban::TYPE_GATHER)
  end

  def privileged?(cuser)
    cuser.admin? || cuser.gather_moderator?
  end

  def captains_turn?(cuser)
    captain = case gather.turn
              when 1 then gather.captain1
              when 2 then gather.captain2
              end
    captain&.user == cuser
  end
end
