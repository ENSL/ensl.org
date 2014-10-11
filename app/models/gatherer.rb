# == Schema Information
#
# Table name: gatherers
#
#  id         :integer          not null, primary key
#  user_id    :integer
#  gather_id  :integer
#  team       :integer
#  created_at :datetime
#  updated_at :datetime
#  votes      :integer          default(0), not null
#

class Gatherer < ActiveRecord::Base
  IDLE_TIME = 600
  EJECT_VOTES = 4

  STATE_ACTIVE = 0
  STATE_AWAY = 1
  STATE_LEAVING = 2

  include Extra

  attr_protected :id
  attr_accessor :confirm, :username
  cattr_accessor :skip_callbacks

  scope :team,
    lambda { |team| {:conditions => {:team => team}} }
  scope :of_user,
    lambda { |user| {:conditions => {:user_id => user.id}} }
  scope :lobby, :conditions => "team IS NULL"
  scope :best,
    lambda { |gather| {
    :select => "u.id, u.username, (COUNT(*) / (SELECT COUNT(*) FROM gatherers g3 WHERE g3.user_id = u.id)) AS skill, g4.id",
    :from => "gathers g1",
    :joins => "LEFT JOIN gatherers g2 ON g1.captain1_id = g2.id OR g1.captain2_id = g2.id
  LEFT JOIN users u ON g2.user_id = u.id
  LEFT JOIN gatherers g4 ON u.id = g4.user_id AND g4.gather_id = #{gather.id}",
    :group => "u.id",
    :having => "g4.id IS NOT NULL",
    :order => "skill DESC",
    :limit => 15 } }
  scope :with_kpd,
    :select => "gatherers.*, SUM(kills)/SUM(deaths) as kpd, COUNT(rounders.id) as rounds",
    :joins => "LEFT JOIN rounders ON rounders.user_id = gatherers.user_id",
    :group => "rounders.user_id",
    :order => "kpd DESC"
  scope :lobby_team,
    lambda { |team| {
    :conditions => ["gatherers.team IS NULL OR gatherers.team = ?", team],
    :order => "gatherers.team"} }
  scope :most_voted, :order => "votes DESC, created_at DESC"
  scope :not_user,
    lambda { |user| {:conditions => ["user_id != ?", user.id]} }
  scope :eject_order, :order => "votes ASC"
  scope :ordered,
    :joins => "LEFT JOIN gathers ON captain1_id = gatherers.id OR captain2_id = gatherers.id",
    :order => "captain1_id, captain2_id, gatherers.id"
  scope :idle,
    :joins => "LEFT JOIN users ON users.id = gatherers.user_id",
    :conditions => ["lastvisit < ?", 30.minutes.ago.utc]

  belongs_to :user
  belongs_to :gather
  has_many :real_votes, :class_name => "Vote", :as => :votable, :dependent => :destroy

  validates_uniqueness_of :user_id, :scope => :gather_id
  validates_inclusion_of :team, :in => 1..2, :allow_nil => true
  validates :confirm, :acceptance => true, :unless => Proc.new {|gatherer| gatherer.user.gatherers.count >= 5}
  validate :validate_username

  after_create :start_gather, :if => Proc.new {|gatherer| gatherer.gather.gatherers.count == Gather::FULL}
  after_create :notify_gatherers, :if => Proc.new {|gatherer| gatherer.gather.gatherers.count == Gather::NOTIFY}
  after_update :change_turn, :unless => Proc.new {|gatherer| gatherer.skip_callbacks == true}
  after_destroy :cleanup_votes

  def to_s
    user.to_s
  end

  def validate_username
    if username
      if u = User.first(:conditions => {:username => username})
        self.user = u
      else
        errors.add(:username, t(:gatherer_wrong_username))
      end
    end
  end

  def start_gather
    gather.update_attribute :status, Gather::STATE_VOTING
    # Create a new shout msgs when the gather is full
    Shoutmsg.new({
      :shoutable_type => gather.class.to_s,
      :shoutable_id => gather.id,
      :text => I18n.t(:gather_start_shout)
    }).save
  end

  def notify_gatherers
    Profile.all(:include => :user, :conditions => "notify_gather = 1").each do |p|
      Notifications.gather p.user, gather if p.user
    end
  end

  def change_turn
    if team_changed? and team != nil
      new_turn = (team == 1 ? 2 : 1)
      if team == 2 and [2, 4].include?(gather.gatherers.team(2).count.to_i)
        new_turn = 2
      elsif team == 1 and [3, 5].include?(gather.gatherers.team(1).count.to_i)
        new_turn = 1
      end
      gather.update_attribute :turn, new_turn
      if gather.gatherers.lobby.count == 1
        gather.gatherers.lobby.first.update_attribute :team, (self.team == 1 ? 2 : 1)
      end
      if gather.gatherers.lobby.count == 0
        gather.update_attribute :status, Gather::STATE_FINISHED
      end
    end
  end

  def cleanup_votes
    gather.map_votes.all(:conditions => {:user_id => user_id}).each { |g|  g.destroy }
    gather.server_votes.all(:conditions => {:user_id => user_id}).each { |g| g.destroy }
    gather.gatherer_votes.all(:conditions => {:user_id => user_id}).each { |g|  g.destroy }
  end

  def votes_needed?
    return 5
  end

  def captain?
    gather.captain1 == self or gather.captain2 == self
  end

  def turn?
    (gather.captain1 == self and gather.turn == 1) or (gather.captain2 == self and gather.turn == 2)
  end

  def can_create? cuser, params = {}
    # and check_params(params, [:user_id, :gather_id])
    cuser \
      and user == cuser \
      and !cuser.banned?(Ban::TYPE_GATHER) \
      and gather.status == Gather::STATE_RUNNING \
      and gather.gatherers.count < Gather::FULL \
      and !gather.gatherers.of_user(cuser).first
  end

  def can_update? cuser, params = {}
    return false unless cuser
    if params.keys.include? "username"
      if cuser.admin?
        return true
      else
        return false
      end
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

  def can_destroy? cuser
    cuser and ((user == cuser or cuser.admin?) and gather.status == Gather::STATE_RUNNING)
  end
end
