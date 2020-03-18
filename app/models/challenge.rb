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
#  status        :integer          default("0"), not null
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

class Challenge < ActiveRecord::Base
  include Extra

  STATUS_PENDING = 0
  STATUS_ACCEPTED = 1
  STATUS_DEFAULT = 2
  STATUS_FORFEIT = 3
  STATUS_DECLINED = 4
  AUTO_DEFAULT_TIME = 10800							# Normal default time: 3 hours
  CHALLENGE_BEFORE_MANDATORY = 432000		# Min. time threshold for mandatory matches: 5 days
  CHALLENGE_BEFORE_VOLUNTARY = 900			# Min. time threshold for voluntary matches: 15 mins
  ACCEPT_BEFORE_MANDATORY = 86400				# Time to accept before mandatory match time: 1 day
  ACCEPT_BEFORE_VOLUNTARY = 300					# Time to accept before voluntary match time: 5 mins
  MATCH_LENGTH = 7200										# Usual match length (for servers): 2 hours

  #attr_protected :id, :updated_at, :created_at, :default_time, :user_id, :status

  validates_presence_of :contester1, :contester2
  validates_presence_of :map2, :on => :update
  #validates_datetime :match_time, :default_time
  #validates_length_of [:details, :response], :maximum => 255, :allow_blank => true, :allow_nil => true
  #validate_on_create:validate_teams
  #validate_on_create:validate_contest
  #validate_on_create:validate_mandatory
  #validate_on_create:validate_match_time
  #validate_on_create:validate_server
  #validate_on_create:validate_map1
  #validate_on_update :validate_map2
  #validate_on_update :validate_status

  scope :category, -> (cat) { where(category_id: cat) }

  scope :of_contester, -> (contester) { where("contester1_id = ? OR contester2_id = ?", contester.id, contester.id) }
  scope :within_time, -> (from, to) { where("match_time > ? AND match_time < ?", from.utc, to.utc) }
  scope :around, -> (time) {  where("match_time > ? AND match_time < ?",  time.ago(MATCH_LENGTH).utc, time.ago(-MATCH_LENGTH).utc) }
  scope :on_week, -> (time) { where("match_time > ? and match_time < ?", time.beginning_of_week, time.end_of_week) }
  scope :pending, -> { where(status: STATUS_PENDING) }
  scope :mandatory, -> { where(mandatory: true) }
  scope :future, -> { where("match_time > UTC_TIMESTAMP()") }
  scope :past, -> { where("match_time < UTC_TIMESTAMP()") }

  has_one :match
  
  belongs_to :map1, :class_name => "Map"
  belongs_to :map2, :class_name => "Map"
  belongs_to :user
  belongs_to :server
  belongs_to :contester1, :class_name => "Contester"
  belongs_to :contester2, :class_name => "Contester"

  def statuses
    {STATUS_PENDING => "Pending response",
     STATUS_ACCEPTED => "Accepted",
     STATUS_DEFAULT => "Default Time",
     STATUS_FORFEIT => "Forfeited",
     STATUS_DECLINED => "Declined"}
  end

  def autodefault
    match_time - (mandatory ? ACCEPT_BEFORE_MANDATORY : ACCEPT_BEFORE_VOLUNTARY)
  end

  def get_margin
    mandatory ? CHALLENGE_BEFORE_MANDATORY : CHALLENGE_BEFORE_VOLUNTARY
  end

  def get_deadline
    mandatory ? ACCEPT_BEFORE_MANDATORY : ACCEPT_BEFORE_VOLUNTARY
  end

  def get_contester1
    self.contester1 = user.active_contesters.of_contest(contester2.contest).first
  end

  def before_validation_on_create
    self.status = STATUS_PENDING
    self.default_time = match_time.end_of_week.change \
      :hour => contester1.contest.default_time.hour,
      :minute => contester1.contest.default_time.strftime("%M").to_i
  end

  def after_create
    contester2.team.teamers.active.leaders.each do |teamer|
      if teamer.user.profile.notify_pms
        Notifications.challenge teamer.user, self
      end
    end
  end

  def validate_teams
    if contester1.team == contester2.team
      errors.add :base, I18n.t(:challenges_yourself)
    end
    if contester1.contest != contester2.contest
      errors.add :base, I18n.t(:challenges_opponent_contest)
    end
    if !contester2.active or !contester2.team.active
      errors.add :base, I18n.t(:challenges_opponent_inactive)
    end
    if !contester1.active or !contester1.team.active
      errors.add :base, I18n.t(:challenges_inactive)
    end
  end

  def validate_contest
    if contester1.contest.end.past? or contester1.contest.status == Contest::STATUS_CLOSED
      errors.add :base, I18n.t(:contests_closed)
    end
    if contester1.contest.contest_type != Contest::TYPE_LADDER and !match
      errors.add :base, I18n.t(:contests_notladder)
    end
  end

  def validate_mandatory
  #  return unless mandatory

  #  if contester2.score < contester1.score
  #    errors.add :base, I18n.t(:challenges_mandatory)
  #  end
  #  if Challenge.pending.count(:conditions =>  \
  #                             ["contester1_id = ? AND contester2_id = ? AND	mandatory = true AND default_time < UTC_TIMESTAMP()",
  #                              contester1.id, contester2.id]) > 0
  #    errors.add :base, I18n.t(:challenges_mandatory_handled)
  #  end
  #  if Match.of_contester(contester2).on_week(match_time).count > 0
  #    errors.add :base, I18n.t(:challenges_opponent_week)
  #  end
  #  if Challenge.of_contester(contester2).mandatory.on_week(match_time).count > 0
  #    errors.add :base, I18n.t(:challenges_opponent_mandatory_week)
  #  end
  #  if Challenge.of_contester(contester2).mandatory.on_week(default_time).count > 0
  #    errors.add :base, I18n.t(:challenges_opponent_mandatory_week_defaulttime)
  #  end
  #  if Match.of_contester(contester2).around(default_time).count > 0
  #    errors.add :base, I18n.t(:challenges_opponent_defaulttime)
  #  end
  end

  def validate_match_time
#    if (match_time-get_margin).past?
#      if get_margin > 86400
#        errors.add :base, I18n.t(:matches_time1) + get_margin / 60 / 60 / 24 + I18n.t(:matches_time2)
#      else
#        errors.add :base, I18n.t(:matches_time1) + get_margin / 60 + I18n.t(:matches_time3)
#      end
#    end
#    if Challenge.of_contester(contester2).around(match_time).pending.count > 0
#      errors.add :base, I18n.t(:challenges_opponent_specifictime)
#    end
#    if Match.of_contester(contester2).around(match_time).count > 0
#      errors.add :base, I18n.t(:challenges_opponent_match_specifictime)
#    end
#    if match_time > contester1.contest.end
#      errors.add :base, I18n.t(:contests_end)
#    end
  end

  def validate_server
 #   unless server and server.official
 #     errors.add :base, I18n.t(:servers_notavailable)
 #   end
 #   unless server.is_free match_time
 #     errors.add :base, I18n.t(:servers_notfree_specifictime)
 #   end
 #   if !server.is_free default_time
 #     errors.add :base, I18n.t(:servers_notfree_defaulttime)
 #   end
  end

  def validate_map1
    unless contester1.contest.maps.exists?(map1)
      errors.add :base, I18n.t(:contests_map_notavailable)
    end
  end

  def validate_map2
    unless contester2.contest.maps.exists?(map2)
      errors.add :base, I18n.t(:contests_map_notavailable)
    end
  end

  def validate_status
    if mandatory and ![STATUS_ACCEPTED, STATUS_DEFAULT, STATUS_FORFEIT].include? status
      errors.add :base, I18n.t(:challenges_mandatory_invalidresult)
    end
    unless statuses.include? status
      errors.add :base, I18n.t(:challenges_mandatory_invalidresult)
    end
  end

  def after_update
    if status_changed?
      if status == STATUS_ACCEPTED
        make_match.save
      elsif status == STATUS_DEFAULT
        m = make_match
        m.match_time = default_time
        m.save
      elsif status == STATUS_FORFEIT
        m = make_match
        m.forfeit = true
        m.score1 = 4
        m.score2 = 0
        m.match_time = default_time
        m.save
      end
    end
  end

  def make_match
    match = Match.new
    match.contester1 = contester1
    match.contester2 = contester2
    match.map1 = map1
    match.map2 = map2
    match.contest = contester1.contest
    match.challenge = self
    match.server = server
    match.match_time = match_time
    match
  end

  def can_create? cuser
    return false unless cuser
    return false if cuser.banned?(Ban::TYPE_LEAGUE)
    validate_teams
    validate_contest
    true if (contester1.team.is_leader?(cuser) or cuser.admin?) and errors.size == 0
  end

  def can_update? cuser
    cuser and (contester2.team.is_leader? cuser or cuser.admin?) and status == STATUS_PENDING# and autodefault.future?
  end

  def can_destroy? cuser
    cuser and (contester1.team.is_leader? cuser or cuser.admin?) and status == STATUS_PENDING# and autodefault.future?
  end

  def self.params params, cuser
    params.require(:challenge).permit(:contester1_id, :contester2_id, :match_time, :mandatory, :server_id, :details, :response, :map1_id, :map2_id)
  end
end
