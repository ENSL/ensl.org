# frozen_string_literal: true

# == Schema Information
#
# Table name: contesters
#
#  id         :integer          not null, primary key
#  active     :boolean          default(TRUE), not null
#  draw       :integer          default(0), not null
#  extra      :integer          not null
#  loss       :integer          default(0), not null
#  score      :integer          default(0), not null
#  trend      :integer          not null
#  win        :integer          default(0), not null
#  created_at :datetime
#  updated_at :datetime
#  contest_id :integer
#  team_id    :integer
#
# Indexes
#
#  index_contesters_on_contest_id  (contest_id)
#  index_contesters_on_team_id     (team_id)
#

class Contester < ActiveRecord::Base
  include Extra

  TREND_FLAT = 0
  TREND_UP = 1
  TREND_DOWN = 2

  # attr_protected :id, :updated_at, :created_at, :trend
  attr_accessor :user

  belongs_to :team, optional: true
  belongs_to :contest, optional: true

  scope :active, -> { includes(:team).where(active: true) }
  # ranked is used for ladder. lower score the higher the rank
  scope :ranked, -> { order('score ASC, win DESC, loss ASC').select('contesters.*') }
  scope :ordered, lambda {
    select('contesters.*, (score + extra) AS total_score').order('total_score DESC, score DESC, win DESC, loss ASC')
  }
  scope :chronological, -> { order('created_at DESC') }
  scope :of_contest, ->(contest) { where('contesters.contest_id', contest.id) }

  has_many :challenges_sent, class_name: 'Challenge', foreign_key: 'contester1_id'
  has_many :challenges_received, class_name: 'Challenge', foreign_key: 'contester2_id'
  has_many :matches, lambda {
    where('(contester1_id = contesters.id OR contester2_id = contesters.id)')
  }, through: :contest

  validates_presence_of :team, :contest
  validates_inclusion_of %i[score win loss draw extra], in: 0..9999, allow_nil: true
  validates_uniqueness_of :team_id, scope: :contest_id, message: "You can't join same contest twice."

  # validate_on_create:validate_member_participation
  validate :validate_contest, on: :create
  # validate_on_create:validate_playernumber

  before_create :init_variables

  def to_s
    team.to_s
  end

  def total
    score + extra.to_i
  end

  def statuses
    { false => 'Inactive', true => 'Active' }
  end

  def lineup
    contest.status == Contest::STATUS_CLOSED ? team.teamers.distinct : team.teamers.active
  end

  def get_matches
    contest.matches.where('contester1_id = ? OR contester2_id = ?', id, id)
  end

  def stats_from_matches(matches_scope = nil)
    matches = matches_scope || get_matches.realfinished
    stats = { win: 0, loss: 0, draw: 0 }

    matches.each do |match|
      if match.score1 == match.score2
        stats[:draw] += 1
      elsif match.contester1_id == id
        match.score1 > match.score2 ? stats[:win] += 1 : stats[:loss] += 1
      else
        match.score2 > match.score1 ? stats[:win] += 1 : stats[:loss] += 1
      end
    end

    stats
  end

  def init_variables
    self.active = true
    self.trend = Contester::TREND_FLAT
    self.extra = 0

    # Initialize ladder contesters with sequential scores to avoid negative values during rank updates
    # But only if score was not explicitly set
    return unless contest&.contest_type == Contest::TYPE_LADDER
    return if score.present?

    # Get the current max score in this ladder, default to -1 so first contester gets 0
    max_score = contest.contesters.maximum(:score) || -1
    self.score = max_score + 1
  end

  def validate_member_participation
    # FIXME: some bug here
    #		for member in team.teamers.present do
    #			for team in member.user.active_teams do
    #				if team.contesters.active.exists?(:contest_id => contest_id)
    #					errors.add_to_base "Member #{member.user} is already participating with team #{team.name}"
    #				end
    #			end
    #		end
  end

  def validate_contest
    if contest.end.past?
      errors.add :base, 'Cannot join contest! It is already over!'
    elsif contest.status != Contest::STATUS_OPEN
      errors.add :base, 'Cannot join contest! Signups are closed!'
    end
  end

  def validate_playernumber
    return unless team.teamers.active.unique_by_team.count < 6

    errors.add :team, I18n.t(:contests_join_need6)
  end

  def destroy
    update_attribute :active, false
  end

  def can_create?(cuser, params = {})
    return false unless cuser
    return false if cuser.banned?(Ban::TYPE_LEAGUE)
    return true if cuser.admin?
    return true if team.is_leader?(cuser) && Verification.contain(params, %i[team_id contest_id])

    false
  end

  def can_update?(cuser)
    !!(cuser && cuser.admin?)
  end

  def can_destroy?(cuser)
    !!(cuser && (team.is_leader?(cuser) || cuser.admin?))
  end

  def self.params(params, _cuser)
    params.require(:contester).permit(:team_id, :score, :win, :loss, :draw, :contest_id, :active, :extra, :user)
  end
end
