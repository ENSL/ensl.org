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

class Gatherer < ActiveRecord::Base
  IDLE_TIME = 600
  EJECT_VOTES = 4

  STATE_ACTIVE = 0
  STATE_AWAY = 1
  STATE_LEAVING = 2

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
            select: 'u.id, u.username, (COUNT(*) / (SELECT COUNT(*) FROM gatherers g3 WHERE g3.user_id = u.id)) AS skill, g4.id',
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
  scope :idle, lambda {
    joins('LEFT JOIN users ON users.id = gatherers.user_id')
      .where('lastvisit < ?', 30.minutes.ago.utc)
  }

  belongs_to :user, optional: true
  belongs_to :gather, optional: true
  has_many :real_votes, class_name: 'Vote', as: :votable, dependent: :destroy

  validates_uniqueness_of :user_id, scope: :gather_id
  validates_inclusion_of :team, in: 1..2, allow_nil: true
  validates :confirm, acceptance: true, unless: proc { |gatherer| gatherer.user.gatherers.count >= 5 }
  validate :validate_username

  after_create :start_gather, if: proc { |gatherer| gatherer.gather.gatherers.count == Gather::FULL }
  after_create :notify_gatherers, if: proc { |gatherer| gatherer.gather.gatherers.count == Gather::NOTIFY }
  after_update :change_turn, unless: proc { |gatherer| gatherer.skip_callbacks == true }
  after_destroy :cleanup_votes

  def to_s
    user.to_s
  end

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

    Profile.where(notify_gather: 1).includes(:user).each do |p|
      Notifications.gather p.user, gather if p.user && p.user.profile && p.user.profile.notify_pms
    end
  end

  def change_turn
    return unless (respond_to?(:saved_change_to_team?) ? saved_change_to_team? : team_changed?) and !team.nil?

    # Perform all related state updates under a DB lock to avoid races
    gather.with_lock do
      new_turn = (team == 1 ? 2 : 1)
      if team == 2 and [2, 4].include?(gather.gatherers.team(2).count.to_i)
        new_turn = 2
      elsif team == 1 and [3, 5].include?(gather.gatherers.team(1).count.to_i)
        new_turn = 1
      end
      gather.update!(turn: new_turn)

      if gather.gatherers.lobby.count == 1
        g = gather.gatherers.lobby.first
        g.update!(team: (team == 1 ? 2 : 1))
      end

      gather.update!(status: Gather::STATE_FINISHED) if gather.gatherers.lobby.count == 0
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

  def can_create?(cuser, params = {})
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
      return true if cuser.admin? or cuser.gather_moderator?

      return false

    end
    return false unless team.nil? \
      and ((gather.captain1.user == cuser and gather.turn == 1) or (gather.captain2.user == cuser and gather.turn == 2))
    return false if gather.turn == 1 and gather.gatherers.team(1).count == 2 and gather.gatherers.team(2).count < 3
    return false if gather.turn == 2 and gather.gatherers.team(1).count < 4 and gather.gatherers.team(2).count == 3
    return false if gather.turn == 1 and gather.gatherers.team(1).count == 4 and gather.gatherers.team(2).count < 5
    return false if gather.turn == 2 and gather.gatherers.team(1).count < 6 and gather.gatherers.team(2).count == 5
    return false if gather.turn == 1 and gather.gatherers.team(1).count == 6

    true
  end

  def can_destroy?(cuser)
    cuser and ((user == cuser or cuser.admin? or cuser.gather_moderator?) and gather.status == Gather::STATE_RUNNING)
  end

  def self.params(params, cuser)
    params.require(:gatherer).permit(:status, :username, :user_id, :gather_id, :team, :votes, :confirm)
  end
end
