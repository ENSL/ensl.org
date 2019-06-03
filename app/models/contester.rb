# == Schema Information
#
# Table name: contesters
#
#  id         :integer          not null, primary key
#  team_id    :integer
#  created_at :datetime
#  updated_at :datetime
#  score      :integer          default(0), not null
#  win        :integer          default(0), not null
#  loss       :integer          default(0), not null
#  draw       :integer          default(0), not null
#  contest_id :integer
#  trend      :integer          not null
#  extra      :integer          not null
#  active     :boolean          default(TRUE), not null
#

class Contester < ActiveRecord::Base
  include Extra

  TREND_FLAT = 0
  TREND_UP = 1
  TREND_DOWN = 2

  attr_protected :id, :updated_at, :created_at, :trend
  attr_accessor :user

  belongs_to :team
  belongs_to :contest

  scope :active, -> { includes(:team).where(active: true) }
  # ranked is used for ladder. lower score the higher the rank
  scope :ranked, -> { order("score ASC, win DESC, loss ASC").select("contesters.*") }
  scope :ordered, -> { select("contesters.*, (score + extra) AS total_score").order("total_score DESC, score DESC, win DESC, loss ASC") }
  scope :chronological, -> { order("created_at DESC") }
  scope :of_contest, -> (contest) { where("contesters.contest_id", contest.id) }

  has_many :challenges_sent, :class_name => "Challenge", :foreign_key => "contester1_id"
  has_many :challenges_received, :class_name => "Challenge", :foreign_key => "contester2_id"
  has_many :matches, -> { where("(contester1_id = contesters.id OR contester2_id = contesters.id)") }, :through => :contest

  validates_presence_of :team, :contest
  validates_inclusion_of [:score, :win, :loss, :draw, :extra], :in => 0..9999, :allow_nil => true
  validates_uniqueness_of :team_id, :scope => :contest_id, :message => "You can't join same contest twice."
  
  #validate_on_create:validate_member_participation
  #validate_on_create:validate_contest
  #validate_on_create:validate_playernumber

  before_create :init_variables


  def to_s
    team.to_s
  end

  def total
    score + extra.to_i
  end

  def statuses
    {false => "Inactive", true => "Active"}
  end

  def lineup
    contest.status == Contest::STATUS_CLOSED ? team.teamers.distinct : team.teamers.active
  end

  def get_matches
    contest.matches.all :conditions => ["contester1_id = ? OR contester2_id = ?", id, id]
  end

  def init_variables
    self.active = true
    self.trend = Contester::TREND_FLAT
    self.extra = 0
  end

  def validate_member_participation
    # TODO joku erhe
    #		for member in team.teamers.present do
    #			for team in member.user.active_teams do
    #				if team.contesters.active.exists?(:contest_id => contest_id)
    #					errors.add_to_base "Member #{member.user} is already participating with team #{team.name}"
    #				end
    #			end
    #		end
  end

  def validate_contest
    if contest.end.past? or contest.status == Contest::STATUS_CLOSED
      errors.add :contest, I18n.t(:contests_closed)
    end
  end

  def validate_playernumber
    if team.teamers.active.unique_by_team.count < 6
      errors.add :team, I18n.t(:contests_join_need6)
    end
  end

  def destroy
    update_attribute :active, false
  end

  def can_create? cuser, params = {}
    return false unless cuser
    return false if cuser.banned?(Ban::TYPE_LEAGUE)
    return true if cuser.admin?
    return true if team.is_leader? cuser and Verification.contain params, [:team_id, :contest_id]
    return false
  end

  def can_update? cuser
    cuser and cuser.admin?
  end

  def can_destroy? cuser
    cuser and team.is_leader? cuser or cuser.admin?
  end
end
