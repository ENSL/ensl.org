# frozen_string_literal: true

# == Schema Information
#
# Table name: matches
#
#  id            :integer          not null, primary key
#  diff          :integer
#  forfeit       :boolean
#  match_time    :datetime
#  points1       :integer
#  points2       :integer
#  report        :text(65535)
#  score1        :integer
#  score2        :integer
#  created_at    :datetime
#  updated_at    :datetime
#  caster_id     :string(255)
#  challenge_id  :integer
#  contest_id    :integer
#  contester1_id :integer
#  contester2_id :integer
#  demo_id       :integer
#  hltv_id       :integer
#  map1_id       :integer
#  map2_id       :integer
#  motm_id       :integer
#  referee_id    :integer
#  server_id     :integer
#  week_id       :integer
#
# Indexes
#
#  index_matches_on_challenge_id       (challenge_id)
#  index_matches_on_contest_id         (contest_id)
#  index_matches_on_contester1_id      (contester1_id)
#  index_matches_on_contester2_id      (contester2_id)
#  index_matches_on_demo_id            (demo_id)
#  index_matches_on_hltv_id            (hltv_id)
#  index_matches_on_map1_id            (map1_id)
#  index_matches_on_map2_id            (map2_id)
#  index_matches_on_match_time         (match_time)
#  index_matches_on_motm_id            (motm_id)
#  index_matches_on_referee_id         (referee_id)
#  index_matches_on_score1_and_score2  (score1,score2)
#  index_matches_on_server_id          (server_id)
#  index_matches_on_week_id            (week_id)
#

class Match < ApplicationRecord
  include Extra

  MATCH_LENGTH = 7200

  include Exceptions

  attr_accessor :lineup, :method, :motm_name, :friendly

  # attr_protected :id, :updated_at, :created_at, :diff, :points1, :points2

  has_many :matchers, dependent: :destroy
  has_many :users, through: :matchers
  has_many :predictions, dependent: :destroy
  has_many :comments, -> { order('created_at') }, as: :commentable, dependent: :destroy, inverse_of: :commentable
  has_many :match_proposals, inverse_of: :match, dependent: :destroy

  belongs_to :challenge, optional: true
  belongs_to :contest, optional: true
  belongs_to :contester1, -> { includes('team') }, class_name: 'Contester', optional: true,
                                                   inverse_of: :matches_as_contester1
  belongs_to :contester2, -> { includes('team') }, class_name: 'Contester', optional: true,
                                                   inverse_of: :matches_as_contester2
  belongs_to :map1, class_name: 'Map', optional: true
  belongs_to :map2, class_name: 'Map', optional: true
  belongs_to :server, optional: true
  belongs_to :referee, class_name: 'User', optional: true
  belongs_to :motm, class_name: 'User', optional: true
  belongs_to :demo, class_name: 'DataFile', optional: true
  belongs_to :week, optional: true
  belongs_to :hltv, class_name: 'Server', optional: true
  belongs_to :stream, class_name: 'Movie', optional: true
  belongs_to :caster, class_name: 'User', optional: true

  scope :future, -> { where('match_time > UTC_TIMESTAMP()') }
  scope :future5, -> { where('match_time > UTC_TIMESTAMP()').limit(5) }
  scope :finished, -> { where('score1 != 0 OR score2 != 0') }
  scope :realfinished, -> { where('score1 IS NOT NULL AND score2 IS NOT NULL') }
  scope :unfinished, -> { where('score1 IS NULL AND score2 IS NULL') }
  scope :unreffed, -> { where(referee_id: nil) }
  scope :ordered, -> { order('match_time DESC') }
  scope :chrono, -> { order('match_time ASC') }
  scope :recent, -> { limit(8) }
  scope :active, -> { where(contest_id: Contest.active.select(:id)) }
  scope :on_week, ->(time) { where('match_time > ? and match_time < ?', time.beginning_of_week, time.end_of_week) }
  scope :of_contester, ->(contester) { where('contester1_id = ? OR contester2_id = ?', contester.id, contester.id) }
  scope :of_user, ->(user) { includes(:matchers).where(matchers: { user_id: user.id }) }
  scope :of_team, lambda { |team|
    where(
      'contester1_id IN (SELECT id FROM contesters WHERE team_id = ?) ' \
      'OR contester2_id IN (SELECT id FROM contesters WHERE team_id = ?)',
      team.id, team.id
    )
  }
  scope :of_userteam, lambda { |user, team|
    includes({ matchers: { contester: :team } }).where(teams: { id: team.id }, matchers: { user_id: user.id })
  }
  scope :around, lambda { |time|
    where('match_time > ? AND match_time < ?', (time - MATCH_LENGTH).utc, (time + MATCH_LENGTH).utc)
  }
  scope :after, ->(time) { where('match_time > ? AND match_time < ?', time.utc, (time + MATCH_LENGTH).utc) }
  scope :map_stats, lambda {
    select('map1_id, COUNT(*) as num, maps.name')
      .joins('LEFT JOIN maps ON maps.id = map1_id')
      .group('map1_id')
      .having('map1_id is not null')
      .order('num DESC')
  }
  scope :year_stats, lambda {
    select("id, DATE_FORMAT(match_time, '%Y') as year, COUNT(*) as num")
      .where("match_time > '2000-01-01 01:01:01'")
      .group('year')
      .order('num DESC')
  }
  scope :month_stats, lambda {
    select("id, DATE_FORMAT(match_time, '%m') as month_n,
                                   DATE_FORMAT(match_time, '%M') as month,
                                   COUNT(*) as num")
      .where("match_time > '2000-01-01 01:01:01'")
      .group('month')
      .order('month_n')
  }

  validates :contester1, :contester2, :contest, presence: true
  validates :score1, :score2, format: /\A[1-9]?[0-9]\z/, allow_nil: true
  validates :report, length: { maximum: 64_000 }, allow_blank: true
  validate :validate_different_teams

  before_create :set_hltv
  after_create :send_notifications
  before_validation :set_motm, if: proc { |match| match.motm_name.present? }
  before_update :reset_contest, if: proc { |match|
    match.will_save_change_to_score1? || match.will_save_change_to_score2?
  }
  before_destroy :reset_contest
  after_save :handle_score_change, if: proc { |match| match.saved_change_to_score1? || match.saved_change_to_score2? }
  after_save :set_predictions, if: proc { |match| match.saved_change_to_score1? || match.saved_change_to_score2? }
  after_destroy :after_destroy

  accepts_nested_attributes_for :matchers, allow_destroy: true

  def to_s
    "#{contester1} vs #{contester2}"
  end

  def score_color
    return 'black' if score1.nil? || score2.nil? || contester1.nil? || contester2.nil?
    return 'yellow' if score1 == score2
    return 'green' if contester1.team == friendly && score1 > score2
    return 'green' if contester2.team == friendly && score2 > score1
    return 'red' if contester1.team == friendly && score1 < score2

    'red' if contester2.team == friendly && score2 < score1
  end

  def preds(contester)
    cont = contester.to_i
    raise ArgumentError, 'invalid contester' unless [1, 2].include?(cont)

    perc = Prediction.where(["match_id = ? AND score#{cont} > 2", id]).count
    perc != 0 ? (perc / predictions.count.to_f * 100).round : 0
  end

  def mercs(contester)
    matchers.where(merc: true, contester_id: contester.id)
  end

  def ensure_hltv
    self.hltv = hltv || Server.hltvs.active.unreserved_hltv_around(match_time).first
  end

  def demo_name
    Verification.uncrap("#{contest.short_name}-#{id}_#{contester1}-vs-#{contester2}")
  end

  def team1_lineup
    matchers.where(contester_id: contester1_id)
  end

  def team2_lineup
    matchers.where(contester_id: contester2_id)
  end

  def get_opposing_team(team)
    team == contester1.team ? contester2.team : contester1.team
  end

  def validate_different_teams
    return if contester1.nil? || contester2.nil?

    return unless contester1.team == contester2.team

    errors.add(:base, :match_same_team_error)
  end

  def set_hltv
    ensure_hltv if match_time && match_time > Time.now.utc
  end

  def send_notifications
    Profile.where('notify_any_match', 1).includes(:user).find_each do |p|
      Notifications.match p.user, self if p.user
    end
    contester2.team.teamers.active.each do |teamer|
      Notifications.challenge teamer.user, self if teamer.user.profile.notify_own_match
    end
  end

  def set_motm
    self.motm = User.find_by(username: motm_name)
    errors.add(:motm_name, 'User not found') unless motm
  end

  def set_predictions
    # rubocop:disable Rails/SkipsModelValidations
    predictions.update_all(result: 0)
    predictions.where(score1: score1, score2: score2).update_all(result: 1)
    # rubocop:enable Rails/SkipsModelValidations
  end

  def after_destroy
    # rubocop:disable Rails/SkipsModelValidations
    predictions.update_all(result: 0)
    # rubocop:enable Rails/SkipsModelValidations
    # reset_contest already reverted the ladder ranks; a full replay would discard manual ordering.
    return if contest.contest_type == Contest::TYPE_LADDER

    contest.recalculate
  end

  # Adjust contesters' points and records to remove this match's effects
  def reset_contest
    return if score1_was.nil? || score2_was.nil?
    return if contest.contest_type == Contest::TYPE_LEAGUE &&
              !contester2.active || !contester1.active

    refresh_ladder_contesters
    revert_records

    return if contest.contest_type == Contest::TYPE_BRACKET

    if contest.contest_type == Contest::TYPE_LADDER
      revert_ladder_ranks
      contester1.save!
      contester2.save!
      self.diff = nil
      return
    end

    contester1.score = contester1.score - score1_was
    contester2.score = contester2.score - score2_was
    contester1.save!
    contester2.save!
  end

  def revert_records
    if score1_was == score2_was
      contester1.draw -= 1
      contester2.draw -= 1
    elsif score1_was > score2_was
      contester1.win -= 1
      contester2.loss -= 1
    else
      contester1.loss -= 1
      contester2.win -= 1
    end
  end

  # update_ranks shuffles ranks with a bulk update, so cached contesters can hold stale ranks.
  def refresh_ladder_contesters
    return unless contest.contest_type == Contest::TYPE_LADDER

    contester1.reload
    contester2.reload
  end

  def move_rank(contester, offset)
    contest.update_ranks(contester, contester.score, contester.score + offset)
  end

  # Undoes the single rank move applied by #apply_ladder_ranks. diff is the rank gap
  # (contester2.score - contester1.score) that was in effect when the match was applied.
  def revert_ladder_ranks
    return if diff.nil?

    if score1_was == score2_was
      revert_ladder_draw
    elsif score1_was > score2_was && diff.negative?
      move_rank(contester1, -diff)
    elsif score1_was < score2_was && diff.positive?
      move_rank(contester2, diff)
    end
  end

  def revert_ladder_draw
    move_rank(contester1, -1 - diff) if diff.negative?
    move_rank(contester2, diff - 1) if diff.positive?
  end

  def handle_score_change
    recalculate
    # recalculate runs after the save cycle, so its columns need persisting without re-firing callbacks.
    columns = slice(:diff, :points1, :points2).select { |name, _| changed.include?(name) }
    # rubocop:disable Rails/SkipsModelValidations
    update_columns(columns) if columns.any?
    # rubocop:enable Rails/SkipsModelValidations
  end

  # Recalculate contesters' points and records based on current match scores
  def recalculate
    return if score1.nil? || score2.nil?
    return if contest.contest_type == Contest::TYPE_LEAGUE &&
              !contester2.active || !contester1.active

    refresh_ladder_contesters
    apply_records

    self.diff = if contest.contest_type == Contest::TYPE_LADDER
                  contester2.score - contester1.score
                else
                  diff || (contester2.score - contester1.score)
                end

    if contest.contest_type == Contest::TYPE_LADDER
      apply_ladder_ranks
    elsif contest.contest_type == Contest::TYPE_LEAGUE
      apply_league_points
    end

    return if contest.contest_type == Contest::TYPE_BRACKET

    contester1.save!
    contester2.save!
  end

  def apply_records
    case score1 <=> score2
    when 0
      contester1.draw += 1
      contester2.draw += 1
    when 1
      contester1.win += 1
      contester2.loss += 1
    else
      contester1.loss += 1
      contester2.win += 1
    end

    contester1.trend = trend_for(score1 <=> score2)
    contester2.trend = trend_for(score2 <=> score1)
  end

  def trend_for(result)
    case result
    when 1 then Contester::TREND_UP
    when -1 then Contester::TREND_DOWN
    else Contester::TREND_FLAT
    end
  end

  def apply_league_points
    self.points1 = score1
    self.points2 = score2
    contester1.score = [contester1.score + points1, 0].max
    contester2.score = [contester2.score + points2, 0].max
  end

  # Ladder rules: beating a better-ranked opponent takes their rank; drawing with one
  # moves you to the position directly below them. Beating a worse-ranked opponent changes nothing.
  def apply_ladder_ranks
    if score1 == score2
      apply_ladder_draw
    elsif score1 > score2 && diff.negative?
      move_rank(contester1, diff)
    elsif score1 < score2 && diff.positive?
      move_rank(contester2, -diff)
    end
  end

  def apply_ladder_draw
    move_rank(contester1, diff + 1) if diff.negative?
    move_rank(contester2, 1 - diff) if diff.positive?
  end

  def hltv_record(addr, pwd)
    if (match_time - MATCH_LENGTH * 10) > Time.now.utc ||
       (match_time + MATCH_LENGTH * 10) < Time.now.utc
      raise Error, I18n.t('hltv_request_20')
    end
    raise Error, I18n.t(:hltv_already) + hltv.addr if hltv&.recording
    raise Error, I18n.t(:hltv_notavailable) unless ensure_hltv

    save!
    hltv.reservation = addr
    hltv.pwd = pwd
    hltv.recordable = self
    hltv.save!
  end

  def hltv_move(addr, pwd)
    raise Error, I18n.t(:hltv_notset) if hltv.nil? || hltv.recording.nil?

    Server.move hltv.reservation, addr, pwd
  end

  def hltv_stop
    raise Error, I18n.t(:hltv_notset) if hltv.nil? || hltv.recording.nil?

    Server.stop hltv.reservation
  end

  def can_create?(cuser)
    cuser&.admin?
  end

  def can_update?(cuser, params = {})
    return false unless cuser
    return true if cuser.admin?

    referee_can_update?(cuser, params) ||
      team_leader_can_update?(cuser, params) ||
      caster_can_update?(cuser, params)
  end

  def can_destroy?(cuser)
    cuser&.admin?
  end

  def can_make_proposal?(cuser)
    !!(cuser && (contester1.team.is_leader?(cuser) || contester2.team.is_leader?(cuser)))
  end

  def user_in_match?(user)
    !!(user && (user.active_team == contester1.team || user.active_team == contester2.team))
  end

  def confirmed_proposal?
    match_proposals.confirmed_for_match(self).exists?
  end

  def self.params(params, _cuser)
    params.require(:match).permit(:diff, :forfeit, :match_time, :points1, :points2, :report, :score1, :score2,
                                  :caster_id, :challenge_id, :contest_id, :contester1_id, :contester2_id,
                                  :demo_id, :hltv_id, :map1_id, :map2_id, :motm_id, :referee_id,
                                  :server_id, :week_id)
  end

  # This method normalizes the matchers_attributes hash in the match_params hash.
  # It ensures that the _destroy attribute is set correctly and that user_id values
  # are valid. It modifies the match_params hash in place.
  def self.normalize_matchers_attributes!(match_params)
    return unless match_params

    matchers_attributes = match_params[:matchers_attributes] || match_params['matchers_attributes']
    return unless matchers_attributes.respond_to?(:keys)

    matchers_attributes.each_key do |key|
      matcher = matchers_attributes[key]
      next unless matcher.respond_to?(:keys)

      destroy_value = matcher[:_destroy] || matcher['_destroy']
      matcher['_destroy'] = destroy_value != 'keep' if matcher.respond_to?(:[]=)

      user_id = matcher[:user_id] || matcher['user_id']
      if user_id.blank?
        matchers_attributes.delete(key)
        next
      end

      next unless user_id.to_i.zero?

      user = User.find_by(username: user_id)
      matcher['user_id'] = user.id if user
    end
  end

  private

  def referee_can_update?(cuser, params)
    return false unless cuser.ref?

    if referee == cuser
      result_fields = %i[score1 score2 forfeit report demo_id motm_name matchers_attributes server_id]
      return true if Verification.contain(params, result_fields)
      return true if Verification.contain(params, [:hltv]) && !demo
    end

    Verification.contain(params, [:referee_id]) &&
      self_assignment_change?(assigned_id: referee_id, requested_id: params[:referee_id], user_id: cuser.id)
  end

  def team_leader_can_update?(cuser, params)
    return false unless team_leader?(cuser)

    leader_result_update?(params) || leader_stream_update?(params)
  end

  def team_leader?(cuser)
    contester1.team.is_leader?(cuser) || contester2.team.is_leader?(cuser)
  end

  def leader_result_update?(params)
    return false unless match_time.past?
    return true if Verification.contain(params, %i[score1 score2]) && [score1, score2, forfeit].none?

    Verification.contain(params, [:matchers_attributes])
  end

  def leader_stream_update?(params)
    match_time.today? && Verification.contain(params, [:stream_id])
  end

  def caster_can_update?(cuser, params)
    cuser.caster? && Verification.contain(params, [:caster_id]) &&
      self_assignment_change?(assigned_id: caster_id, requested_id: params[:caster_id], user_id: cuser.id)
  end

  def self_assignment_change?(assigned_id:, requested_id:, user_id:)
    return requested_id.to_i == user_id if assigned_id.blank?

    assigned_id.to_i == user_id && requested_id.blank?
  end
end
