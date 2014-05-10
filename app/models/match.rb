# == Schema Information
#
# Table name: matches
#
#  id            :integer          not null, primary key
#  contester1_id :integer
#  contester2_id :integer
#  score1        :integer
#  score2        :integer
#  match_time    :datetime
#  challenge_id  :integer
#  contest_id    :integer
#  report        :text
#  created_at    :datetime
#  updated_at    :datetime
#  map1_id       :integer
#  map2_id       :integer
#  server_id     :integer
#  motm_id       :integer
#  demo_id       :integer
#  week_id       :integer
#  referee_id    :integer
#  forfeit       :boolean
#  diff          :integer
#  points1       :integer
#  points2       :integer
#  hltv_id       :integer
#

class Match < ActiveRecord::Base
  include Extra

  MATCH_LENGTH = 7200

  include Exceptions

  attr_accessor :lineup, :method, :motm_name, :friendly
  attr_protected :id, :updated_at, :created_at, :diff, :points1, :points2

  has_many :matchers, :dependent => :destroy
  has_many :users, :through => :matchers
  has_many :predictions, :dependent => :destroy
  has_many :comments, :as => :commentable, :order => "created_at", :dependent => :destroy
  belongs_to :challenge
  belongs_to :contest
  belongs_to :contester1, :class_name => "Contester", :include => 'team'
  belongs_to :contester2, :class_name => "Contester", :include => 'team'
  belongs_to :map1, :class_name => "Map"
  belongs_to :map2, :class_name => "Map"
  belongs_to :server
  belongs_to :referee, :class_name => "User"
  belongs_to :motm, :class_name => "User"
  belongs_to :demo, :class_name => "DataFile"
  belongs_to :week
  belongs_to :hltv, :class_name => "Server"
  belongs_to :stream, :class_name => "Movie"
  belongs_to :caster, :class_name => "User"

  scope :future, :conditions => ["match_time > UTC_TIMESTAMP()"]
  scope :future5, :conditions => ["match_time > UTC_TIMESTAMP()"], :limit => 5
  scope :finished, :conditions => ["score1 != 0 OR score2 != 0"]
  scope :realfinished, :conditions => ["score1 IS NOT NULL AND score2 IS NOT NULL"]
  scope :unfinished, :conditions => ["score1 IS NULL AND score2 IS NULL"]
  scope :unreffed, :conditions => ["referee_id IS NULL"]
  scope :ordered, :order => "match_time DESC"
  scope :chrono, :order => "match_time ASC"
  scope :recent, :limit => "8"
  scope :bigrecent, :limit => "50"
  scope :active, :conditions => ["contest_id IN (?)", Contest.active]
  scope :on_day,
    lambda { |day| {
    :conditions => ["match_time > ? and match_time < ?", day.beginning_of_day, day.end_of_day]} }
  scope :on_week,
    lambda { |time| {
    :conditions => ["match_time > ? and match_time < ?", time.beginning_of_week, time.end_of_week]} }
  scope :of_contester,
    lambda { |contester| {
    :conditions => ["contester1_id = ? OR contester2_id = ?", contester.id, contester.id]} }
  scope :of_user,
    lambda { |user| {
    :include => :matchers,
    :conditions => ["matchers.user_id = ?",  user.id]} }
  scope :of_team,
    lambda { |team| {
    :include => {:contester1 => :team,
                 :contester2 => :team}, :conditions => ["teams.id = ? OR teams_contesters.id = ?", team.id, team.id]} }
  scope :of_userteam,
    lambda { |user, team| {
    :include => {:matchers => {:contester => :team}},
    :conditions => ["teams.id = ? AND matchers.user_id = ?", team.id, user.id]} }
  scope :within_time,
    lambda { |from, to| {
    :conditions => ["match_time > ? AND match_time < ?", from.utc, to.utc]} }
  scope :around,
    lambda { |time| {
    :conditions => ["match_time > ? AND match_time < ?",  time.ago(MATCH_LENGTH).utc, time.ago(-MATCH_LENGTH).utc]} }
  scope :after,
    lambda { |time| {
    :conditions => ["match_time > ? AND match_time < ?",  time.utc, time.ago(-MATCH_LENGTH).utc]} }
  scope :map_stats,
    :select => "map1_id, COUNT(*) as num, maps.name",
    :joins => "LEFT JOIN maps ON maps.id = map1_id",
    :group => "map1_id",
    :having => "map1_id is not null",
    :order => "num DESC"
  scope :year_stats,
    :select => "id, DATE_FORMAT(match_time, '%Y') as year, COUNT(*) as num",
    :conditions => "match_time > '2000-01-01 01:01:01'",
    :group => "year",
    :order => "num DESC"
  scope :month_stats,
    :select => "id, DATE_FORMAT(match_time, '%m') as month_n,
    DATE_FORMAT(match_time, '%M') as month,
    COUNT(*) as num",
    :conditions => "match_time > '2000-01-01 01:01:01'",
    :group => "month",
    :order => "month_n"

  validates_presence_of :contester1, :contester2, :contest
  validates_format_of [:score1, :score2], :with => /\A[0-9]\z/, :allow_nil => true
  validates_length_of :report, :maximum => 64000, :allow_blank => true

  before_create :set_hltv
  after_create :send_notifications
  before_save :set_motm, :if => Proc.new {|match| match.motm_name and !match.motm_name.empty?}
  after_save :recalculate, :if => Proc.new {|match| match.score1_changed? or match.score2_changed?}
  after_save :set_predictions, :if => Proc.new {|match| match.score1_changed? or match.score2_changed?}

  accepts_nested_attributes_for :matchers, :allow_destroy => true

  def to_s
    contester1.to_s + " vs " + contester2.to_s
  end

  def score_color
    return "black" if score1.nil? or score2.nil? or contester1.nil? or contester2.nil?
    return "yellow" if score1 == score2
    return "green" if contester1.team == friendly and score1 > score2
    return "green" if contester2.team == friendly and score2 > score1
    return "red" if contester1.team == friendly and score1 < score2
    "red" if contester2.team == friendly and score2 < score1
  end

  def preds contester
    perc = Prediction.count(:conditions => ["match_id = ? AND score#{contester} > 2", id])
    perc != 0 ? (perc/predictions.count.to_f*100).round : 0
  end

  def mercs contester
    matchers.all :conditions => {:merc => true, :contester_id => contester.id}
  end

  def get_hltv
    self.hltv = hltv ? hltv : Server.hltvs.active.unreserved_hltv_around(match_time).first
  end

  def demo_name
    Verification.uncrap(contest.short_name + "-" + self.id.to_s + "_" + contester1.to_s + "-vs-" + contester2.to_s)
  end

  def team1_lineup
    matchers.all(:conditions => {:contester_id => contester1_id})
  end

  def team2_lineup
    matchers.all(:conditions => {:contester_id => contester2_id})
  end

  def get_friendly param = nil
    if param.nil?
      friendly == contester1.team ? contester1 : contester2
    elsif param == :score
      friendly == contester1.team ? score1 : score2
    elsif param == :points
      friendly == contester1.team ? points1 : points2
    end
  end

  def get_opponent param = nil
    if param.nil?
      friendly == contester1.team ? contester2 : contester1
    elsif param == :score
      friendly == contester1.team ? score2 : score1
    elsif param == :points
      friendly == contester1.team ? points2 : points1
    end
  end

  def set_hltv
    get_hltv if match_time.future?
  end

  def send_notifications
    Profile.all(:include => :user, :conditions => "notify_any_match = 1").each do |p|
      Notifications.match p.user, self if p.user
    end
    contester2.team.teamers.active.each do |teamer|
      if teamer.user.profile.notify_own_match
        Notifications.challenge teamer.user, self
      end
    end
  end

  def set_motm
    self.motm = User.find_by_username(motm_name)
  end

  def set_predictions
    predictions.update_all "result = 0"
    predictions.update_all "result = 1", ["score1 = ? AND score2 = ?", score1, score2]
  end

  def after_destroy
    predictions.update_all "result = 0"
    contest.recalculate
  end

  def recalculate
    return if score1.nil? or score2.nil?
    return if contest.contest_type == Contest::TYPE_LEAGUE and !contester2.active or !contester1.active

    if score1 == score2
      contester1.draw = contester1.draw + 1
      contester2.draw = contester2.draw + 1
      contester1.trend = Contester::TREND_FLAT
      contester2.trend = Contester::TREND_FLAT
    elsif score1 > score2
      contester1.win = contester1.win + 1
      contester2.loss = contester2.loss + 1
      contester1.trend = Contester::TREND_UP
      contester2.trend = Contester::TREND_DOWN
    elsif score1 < score2
      contester1.loss = contester1.loss + 1
      contester2.win = contester2.win + 1
      contester1.trend = Contester::TREND_DOWN
      contester2.trend = Contester::TREND_UP
    end

    self.diff = diff ? diff : (contester2.score-contester1.score)

    if contest.contest_type == Contest::TYPE_LADDER
      self.points1 = contest.elo_score score1, score2, diff
      self.points2 = contest.elo_score score2, score1, -(diff)
    elsif contest.contest_type == Contest::TYPE_LEAGUE
      self.points1 = score1
      self.points2 = score2
    end

    if contest.contest_type == Contest::TYPE_LADDER
      contester1.extra = contester1.extra + contest.modulus_base/10
      contester2.extra = contester2.extra + contest.modulus_base/10
    end

    unless contest.contest_type == Contest::TYPE_BRACKET
      contester1.score = contester1.score+points1 < 0 ? 0 : contester1.score+points1
      contester2.score = contester2.score+points2 < 0 ? 0 : contester2.score+points2
      contester1.save!
      contester2.save!
    end
  end

  def hltv_record addr, pwd
    if (match_time - MATCH_LENGTH*10) > DateTime.now or (match_time + MATCH_LENGTH*10) < DateTime.now
      raise Error, I18n.t(:hltv_request_20)
    end
    if hltv and hltv.recording
      raise Error, I18n.t(:hltv_already) + hltv.addr
    end
    unless get_hltv
      raise Error, I18n.t(:hltv_notavailable)
    end

    save!
    hltv.reservation = addr
    hltv.pwd = pwd
    hltv.recordable = self
    hltv.save!
  end

  def hltv_move addr, pwd
    raise Error, I18n.t(:hltv_notset) if hltv.nil? or hltv.recording.nil?
    Server.move hltv.reservation, addr, pwd
  end

  def hltv_stop
    raise Error, I18n.t(:hltv_notset) if hltv.nil? or hltv.recording.nil?
    Server.stop hltv.reservation
  end

  def can_create? cuser
    cuser and cuser.admin?
  end

  def can_update? cuser, params = {}
    return false unless cuser
    return true if cuser.admin?
    return true if cuser.caster? and Verification.contain params, [:caster_id] \
      and (params[:caster_id] && params[:caster_id].to_i == cuser.id && caster_id.blank?) \
      or (params[:caster_id].blank? && caster_id == cuser.id)
    return true if cuser.ref?  and Verification.contain params, [:referee_id] \
      and (params[:referee_id] && params[:referee_id].to_i == cuser.id  && referee_id.blank?) \
      or (params[:referee_id].blank? && referee_id == cuser.id)
    return true if cuser.ref? and referee == cuser \
      and Verification.contain params, [:score1, :score2, :forfeit, :report, :demo_id, :motm_name, :matchers_attributes, :server_id]
    return true if match_time.past? and !score1 and !score2 and !forfeit \
      and Verification.contain(params, [:score1, :score2]) \
      and (contester1.team.is_leader? cuser or contester2.team.is_leader? cuser)
    return true if match_time.today? \
      and Verification.contain(params, [:stream_id]) \
      and (contester1.team.is_leader? cuser or contester2.team.is_leader? cuser)
    return true if match_time.past? \
      and Verification.contain(params, [:matchers_attributes]) \
      and (contester1.team.is_leader? cuser or contester2.team.is_leader? cuser)
    return true if (cuser.ref? and referee == cuser) \
      and Verification.contain(params, [:hltv]) \
      and !demo
    false
  end

  def can_destroy? cuser
    cuser and cuser.admin?
  end
end
