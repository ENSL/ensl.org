# == Schema Information
#
# Table name: teamers
#
#  id         :integer          not null, primary key
#  comment    :string(255)
#  rank       :integer          not null
#  created_at :datetime
#  updated_at :datetime
#  team_id    :integer          not null
#  user_id    :integer          not null
#
# Indexes
#
#  index_teamers_on_team_id  (team_id)
#  index_teamers_on_user_id  (user_id)
#

class Teamer < ActiveRecord::Base
  include Extra

  RANK_REMOVED = -2
  RANK_JOINER = -1
  RANK_MEMBER = 0
  RANK_DEPUTEE = 1
  RANK_LEADER = 2

  #attr_protected :id, :created_at, :updated_at, :version

  validates_length_of :comment, :in => 0..15, :allow_blank => true
  validates_uniqueness_of :user_id, :scope => [:team_id, :rank]
  validates_presence_of :user, :team
  #validate_on_create:validate_team
  #validate_on_create:validate_contests
  validate :validate_team

  scope :basic, -> { includes(:user).order("rank DESC, created_at ASC") }
  scope :past, -> { where("teamers.rank = ?", RANK_REMOVED) }
  scope :joining,-> { where("teamers.rank = ?", RANK_JOINER) }
  scope :present, -> { where("teamers.rank >= ?", RANK_JOINER) }
  scope :active, -> { where("teamers.rank >= ?", RANK_MEMBER) }
  scope :leaders, -> { where("teamers.rank >= ?", RANK_DEPUTEE) }
  scope :of_team, -> (team) { where("teamers.team_id" => team.id) }
  scope :active_teams, -> { includes(:team).where(teams: {active: true}) }
  scope :unique_by_team, -> { group("user_id, team_id") }
  scope :ordered, -> { order("rank DESC, created_at ASC") }
  scope :historic, ->  (user, time) {
                     where("user_id = ? AND created_at < ? AND ((updated_at > ? AND rank = ?) OR rank >= ?)",
                     user.id, time.utc, time.utc, RANK_REMOVED, RANK_MEMBER) }

  belongs_to :user, :optional => true
  belongs_to :team, :optional => true
  has_many :other_teamers, -> { where("teamers.id != ?", object_id) }, :through => :user, :source => :teamers
  has_many :contesters, :through => :team

  before_create :init_variables

  def to_s
    user.to_s
  end

  def ranks
    {RANK_JOINER => "Joining", RANK_MEMBER => "Member", RANK_DEPUTEE => "Deputee", RANK_LEADER => "Leader"}
  end
  
  def rank_s
    ranks[rank]
  end

  def validate_team
    if user.teamers.of_team(team).present.count > 0
      errors.add :team, I18n.t(:teams_join_twice)
    end
  end

  def validate_contests
    # TODO
  end

  def init_variables
    self.rank = RANK_JOINER unless self.rank
  end

  def destroy
    user.update_attribute :team, nil if user.team == team
    if rank == Teamer::RANK_JOINER
      super
    else
      update_attribute :rank, Teamer::RANK_REMOVED
    end
  end

  def can_create? cuser, params
    cuser and Verification.contain params, [:user_id, :team_id]
  end

  def can_update? cuser
    cuser and cuser.admin?
  end

  def can_destroy? cuser
    cuser and (user == cuser or team.is_leader? cuser or cuser.admin?)
  end

  def self.params(params, cuser)
    params.require(:teamer).permit(:comment, :rank, :team_id, :user_id)
  end
end
