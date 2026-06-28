# frozen_string_literal: true

# == Schema Information
#
# Table name: challenges
#
#  id            :integer          not null, primary key
#  default_time  :datetime
#  details       :string(255)
#  mandatory     :boolean
#  match_time    :datetime
#  response      :string(255)
#  status        :integer          default(0), not null
#  created_at    :datetime
#  updated_at    :datetime
#  contester1_id :integer
#  contester2_id :integer
#  map1_id       :string(255)
#  map2_id       :string(255)
#  server_id     :integer
#  user_id       :integer
#
# Indexes
#
#  index_challenges_on_contester1_id  (contester1_id)
#  index_challenges_on_contester2_id  (contester2_id)
#  index_challenges_on_map1_id        (map1_id)
#  index_challenges_on_map2_id        (map2_id)
#  index_challenges_on_server_id      (server_id)
#  index_challenges_on_user_id        (user_id)
#

# Challenge model
# A challenge is created by a team leader to challenge another team to a match.
# It contains the proposed match time, map, server, and response of the challenged team.
# If accepted, a match is created with the same parameters as the challenge.
class Challenge < ApplicationRecord
  include Extra

  STATUS_PENDING = 0
  STATUS_ACCEPTED = 1
  STATUS_DEFAULT = 2
  STATUS_FORFEIT = 3
  STATUS_DECLINED = 4
  AUTO_DEFAULT_TIME = 10_800 # Normal default time: 3 hours
  CHALLENGE_BEFORE_MANDATORY = 432_000 # Min. time threshold for mandatory matches: 5 days
  CHALLENGE_BEFORE_VOLUNTARY = 900 # Min. time threshold for voluntary matches: 15 mins
  ACCEPT_BEFORE_MANDATORY = 86_400 # Time to accept before mandatory match time: 1 day
  ACCEPT_BEFORE_VOLUNTARY = 300 # Time to accept before voluntary match time: 5 mins
  MATCH_LENGTH = 7200 # Usual match length (for servers): 2 hours

  validates :contester1, :contester2, presence: true
  validates :map2, presence: true, on: :update, unless: lambda { |c|
    [STATUS_ACCEPTED, STATUS_DEFAULT, STATUS_FORFEIT].include?(c.status)
  }
  validates :details, :response, length: { maximum: 255 }, allow_blank: true

  validate :validate_teams, on: :create
  validate :validate_contest, on: :create
  validate :validate_mandatory, on: :create
  validate :validate_match_time, on: :create
  validate :validate_server, on: :create
  validate :validate_map1, on: :create
  validate :validate_map2, on: :update
  validate :validate_status, on: :update

  scope :category, ->(cat) { where(category_id: cat) }
  scope :of_contester, lambda { |contester|
    where('contester1_id = ? OR contester2_id = ?', contester.id, contester.id)
  }
  scope :within_time, ->(from, to) { where('match_time > ? AND match_time < ?', from.utc, to.utc) }
  scope :around, lambda { |time|
    where('match_time > ? AND match_time < ?', time.ago(MATCH_LENGTH).utc, time.ago(-MATCH_LENGTH).utc)
  }
  scope :on_week, ->(time) { where('match_time > ? and match_time < ?', time.beginning_of_week, time.end_of_week) }
  scope :pending, -> { where(status: STATUS_PENDING) }
  scope :mandatory, -> { where(mandatory: true) }
  scope :future, -> { where('match_time > UTC_TIMESTAMP()') }
  scope :past, -> { where('match_time < UTC_TIMESTAMP()') }

  has_one :match, dependent: :nullify

  belongs_to :map1, class_name: 'Map', optional: true
  belongs_to :map2, class_name: 'Map', optional: true
  belongs_to :user, optional: true
  belongs_to :server, optional: true
  belongs_to :contester1, class_name: 'Contester', optional: true
  belongs_to :contester2, class_name: 'Contester', optional: true

  before_validation :set_defaults, on: :create
  after_create :send_challenge_notification
  after_update :apply_status_change, if: :saved_change_to_status?

  def statuses
    {
      STATUS_PENDING => 'Pending response',
      STATUS_ACCEPTED => 'Accepted',
      STATUS_DEFAULT => 'Default Time',
      STATUS_FORFEIT => 'Forfeited',
      STATUS_DECLINED => 'Declined'
    }
  end

  def autodefault
    match_time - (mandatory ? ACCEPT_BEFORE_MANDATORY : ACCEPT_BEFORE_VOLUNTARY)
  end

  def margin
    mandatory ? CHALLENGE_BEFORE_MANDATORY : CHALLENGE_BEFORE_VOLUNTARY
  end

  def deadline
    mandatory ? ACCEPT_BEFORE_MANDATORY : ACCEPT_BEFORE_VOLUNTARY
  end

  def set_contester1
    self.contester1 = user.active_contesters.of_contest(contester2.contest).first
  end

  def self.build_for_new(user:, contester2:)
    challenge = new(user: user, contester2: contester2)
    contest = contester2.contest
    challenge.contester1 = user.active_contesters.of_contest(contest).first
    challenge.match_time = Time.current + 2.days
    challenge
  end

  def apply_commit_status(commit_value)
    self.status = case commit_value
                  when 'Accept'
                    STATUS_ACCEPTED
                  when 'Default time'
                    STATUS_DEFAULT
                  when 'Forfeit'
                    STATUS_FORFEIT
                  when 'Decline'
                    STATUS_DECLINED
                  else
                    status
                  end
  end

  def set_defaults
    self.status = STATUS_PENDING
    # Ensure contest default_time responds to hour/minute; caller tests should set a Time
    return unless contester1&.contest && contester1.contest.default_time.respond_to?(:hour)

    self.default_time = match_time.end_of_week.change(
      hour: contester1.contest.default_time.hour,
      minute: contester1.contest.default_time.strftime('%M').to_i
    )
  end

  def send_challenge_notification
    contester2.team.teamers.active.leaders.each do |teamer|
      Notifications.challenge(teamer.user, self) if teamer.user.profile.notify_pms
    end
  end

  private

  def validate_teams
    errors.add(:base, I18n.t(:challenges_yourself)) if contester1.team == contester2.team
    errors.add(:base, I18n.t(:challenges_opponent_contest)) if contester1.contest != contester2.contest
    errors.add(:base, I18n.t(:challenges_opponent_inactive)) unless contester2.active && contester2.team.active
    return if contester1.active && contester1.team.active

    errors.add(:base, I18n.t(:challenges_inactive))
  end

  def validate_contest
    if contester1.contest.end.past? || (contester1.contest.status == Contest::STATUS_CLOSED)
      errors.add(:base, I18n.t(:contests_closed))
    end
    return unless (contester1.contest.contest_type != Contest::TYPE_LADDER) && !match

    errors.add(:base, I18n.t(:contests_notladder))
  end

  def validate_mandatory
    return unless mandatory

    errors.add(:base, I18n.t(:challenges_mandatory)) if contester2.score < contester1.score

    if Challenge.pending.where(contester1: contester1, contester2: contester2, mandatory: true)
                .where('default_time < UTC_TIMESTAMP()').exists?
      errors.add(:base, I18n.t(:challenges_mandatory_handled))
    end

    errors.add(:base, I18n.t(:challenges_opponent_week)) if Match.of_contester(contester2).on_week(match_time).exists?

    if Challenge.of_contester(contester2).mandatory.on_week(match_time).exists?
      errors.add(:base, I18n.t(:challenges_opponent_mandatory_week))
    end

    if Challenge.of_contester(contester2).mandatory.on_week(default_time).exists?
      errors.add(:base, I18n.t(:challenges_opponent_mandatory_week_defaulttime))
    end

    return unless Match.of_contester(contester2).around(default_time).exists?

    errors.add(:base, I18n.t(:challenges_opponent_defaulttime))
  end

  def validate_match_time
    if (match_time - margin).past?
      if margin > 86_400
        errors.add(:base, "#{I18n.t(:matches_time1)} #{margin / 60 / 60 / 24} #{I18n.t(:matches_time2)}")
      else
        errors.add(:base, "#{I18n.t(:matches_time1)} #{margin / 60} #{I18n.t(:matches_time3)}")
      end
    end

    if Challenge.of_contester(contester2).around(match_time).pending.exists?
      errors.add(:base, I18n.t(:challenges_opponent_specifictime))
    end

    if Match.of_contester(contester2).around(match_time).exists?
      errors.add(:base, I18n.t(:challenges_opponent_match_specifictime))
    end

    return unless match_time > contester1.contest.end

    errors.add(:base, I18n.t(:contests_end))
  end

  def validate_server
    return unless server # Server is optional, only validate if provided

    unless server.official
      errors.add(:base, I18n.t(:servers_notavailable))
      return
    end

    errors.add(:base, I18n.t(:servers_notfree_specifictime)) unless server.is_free(match_time)

    return if server.is_free(default_time)

    errors.add(:base, I18n.t(:servers_notfree_defaulttime))
  end

  def validate_map1
    return unless map1 # Map1 is optional, only validate if provided
    return if contester1.contest.maps.exists?(map1.id)

    errors.add(:base, I18n.t(:contests_map_notavailable))
  end

  def validate_map2
    return unless map2 # Only validate if map2 is provided

    return if contester2.contest.maps.exists?(map2.id)

    errors.add(:base, I18n.t(:contests_map_notavailable))
  end

  def validate_status
    if mandatory && ![STATUS_ACCEPTED, STATUS_DEFAULT, STATUS_FORFEIT].include?(status)
      errors.add(:base, I18n.t(:challenges_mandatory_invalidresult))
    end
    return if statuses.key?(status)

    errors.add(:base, I18n.t(:challenges_mandatory_invalidresult))
  end

  def apply_status_change
    case status
    when STATUS_ACCEPTED
      create_accepted_match
    when STATUS_DEFAULT
      create_default_match
    when STATUS_FORFEIT
      create_forfeit_match
    end
  end

  def create_accepted_match
    make_match.save
  end

  def create_default_match
    m = make_match
    m.match_time = default_time
    m.save
  end

  def create_forfeit_match
    m = make_match
    m.forfeit = true
    m.score1 = 4
    m.score2 = 0
    m.match_time = default_time
    m.save
  end

  def make_match
    Match.new(
      contester1: contester1,
      contester2: contester2,
      map1: map1,
      map2: map2,
      contest: contester1.contest,
      challenge: self,
      server: server,
      match_time: match_time
    )
  end

  public

  def can_create?(cuser)
    return false unless cuser
    return false unless contester1 && contester2
    return false if cuser.banned?(Ban::TYPE_LEAGUE)

    validate_teams
    validate_contest
    (contester1.team.is_leader?(cuser) || cuser.admin?) && errors.empty?
  end

  def can_update?(cuser)
    cuser && (contester2.team.is_leader?(cuser) || cuser.admin?) && status == STATUS_PENDING
  end

  def can_destroy?(cuser)
    cuser && (contester1.team.is_leader?(cuser) || cuser.admin?) && status == STATUS_PENDING
  end

  def self.params(params, _cuser)
    params.require(:challenge).permit(
      :contester1_id, :contester2_id, :match_time, :mandatory,
      :server_id, :details, :response, :map1_id, :map2_id
    )
  end
end
