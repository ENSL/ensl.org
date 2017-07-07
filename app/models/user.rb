# == Schema Information
#
# Table name: users
#
#  id           :integer          not null, primary key
#  username     :string(255)
#  password     :string(255)
#  firstname    :string(255)
#  lastname     :string(255)
#  email        :string(255)
#  steamid      :string(255)
#  team_id      :integer
#  lastvisit    :datetime
#  created_at   :datetime
#  updated_at   :datetime
#  lastip       :string(255)
#  country      :string(255)
#  birthdate    :date
#  time_zone    :string(255)
#  version      :integer
#  public_email :boolean          default(FALSE), not null
#

require 'country_code_select/countries'
require 'digest/md5'
require File.join(Rails.root, 'vendor', 'plugins', 'acts_as_versioned', 'lib', 'acts_as_versioned.rb')

class User < ActiveRecord::Base
  include Extra
  
  VERIFICATION_TIME = 604800

  attr_protected :id, :created_at, :updated_at, :lastvisit, :lastip, :password, :version
  attr_accessor :raw_password

  belongs_to :team
  has_one :profile, :dependent => :destroy
  has_many :bans, :dependent => :destroy
  has_many :articles, :dependent => :destroy
  has_many :movies, :dependent => :destroy
  has_many :servers, :dependent => :destroy
  has_many :votes, :dependent => :destroy
  has_many :gatherers, :dependent => :destroy
  has_many :gathers, :through => :gatherers
  has_many :groupers, :dependent => :destroy
  has_many :posts, :dependent => :destroy
  has_many :groups, :through => :groupers
  has_many :shoutmsgs, :dependent => :destroy
  has_many :issues, :foreign_key => "author_id", :dependent => :destroy
  has_many :open_issues, :class_name => "Issue", :foreign_key => "assigned_id",
    :conditions => ["issues.status = ?", Issue::STATUS_OPEN]
  has_many :posted_comments, :dependent => :destroy, :class_name => "Comment"
  has_many :comments, :class_name => "Comment", :as => :commentable, :order => "created_at ASC", :dependent => :destroy
  has_many :teamers, :dependent => :destroy
  has_many :active_teams, :through => :teamers, :source => "team",
    :conditions => ["teamers.rank >= ? AND teams.active = ?", Teamer::RANK_MEMBER, true]
  has_many :active_contesters, :through => :active_teams, :source => "contesters",
    :conditions => {"contesters.active" => true}
  has_many :active_contests, :through => :active_contesters, :source => "contest",
    :conditions => ["contests.status != ?", Contest::STATUS_CLOSED]
  has_many :past_teams, :through => :teamers, :source => "team", :group => "user_id, team_id"
  has_many :matchers, :dependent => :destroy
  has_many :matches, :through => :matchers
  has_many :predictions, :dependent => :destroy
  has_many :challenges_received, :through => :active_contesters, :source => "challenges_received"
  has_many :challenges_sent, :through => :active_contesters, :source => "challenges_sent"
  has_many :upcoming_team_matches, :through => :active_contesters, :source => "matches",
    :conditions => "match_time > UTC_TIMESTAMP()"
  has_many :upcoming_ref_matches, :class_name => "Match", :foreign_key => "referee_id",
    :conditions => "match_time > UTC_TIMESTAMP()"
  has_many :past_team_matches, :through => :active_contesters, :source => "matches",
    :conditions => "match_time < UTC_TIMESTAMP()"
  has_many :past_ref_matches, :class_name => "Match", :foreign_key => "referee_id",
    :conditions => "match_time < UTC_TIMESTAMP()"
  has_many :received_personal_messages, :class_name => "Message", :as => "recipient", :dependent => :destroy
  has_many :received_team_messages, :through => :active_teams, :source => :received_messages
  has_many :sent_personal_messages, :class_name => "Message", :as => "sender", :dependent => :destroy
  has_many :sent_team_messages, :through => :active_teams, :source => :sent_messages
  has_many :match_teams, :through => :matchers, :source => :teams, :uniq => true

  scope :active, :conditions => {:banned => false}
  scope :with_age,
    :select => "DATE_FORMAT(FROM_DAYS(TO_DAYS(NOW())-TO_DAYS(birthdate)), '%Y')+0 AS aged, COUNT(*) as num, username",
    :group => "aged",
    :having => "num > 8 AND aged > 0"
  scope :country_stats,
    :select => "country, COUNT(*) as num",
    :conditions => "country is not null and country != '' and country != '--'",
    :group => "country",
    :having => "num > 15",
    :order => "num DESC"
  scope :posts_stats,
    :select => "users.id, username, COUNT(posts.id) as num",
    :joins => "LEFT JOIN posts ON posts.user_id = users.id",
    :group => "users.id",
    :order => "num DESC"
  scope :banned,
    :joins => "LEFT JOIN bans ON bans.user_id = users.id AND expiry > UTC_TIMESTAMP()",
    :conditions => "bans.id IS NOT NULL"
  scope :idle,
    :conditions => ["lastvisit < ?", 30.minutes.ago.utc]
  scope :lately,
    :conditions => ["lastvisit > ?", 30.days.ago.utc]

  before_validation :update_password

  validates :username, uniqueness: true, length: {in: 2..20}, format: /\A[A-Za-z0-9_\-\+]{2,20}\Z/
  validates :firstname, length: {in: 1..15}, allow_blank: true
  validates :lastname, length: {in: 1..25}, allow_blank: true
  validates :raw_password, presence: {on: :create}
  validates :email, uniqueness: true, length: {maximum: 50}, format: /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i
  validates :steamid, uniqueness: {allow_nil: true}, length: {maximum: 14}, presence: {on: :create}
  validate :validate_steamid
  validates :time_zone, length: {maximum: 100}, allow_blank: true
  validates :public_email, inclusion: [true, false], allow_nil: true
  validate :validate_team

  before_create :init_variables

  before_save :correct_steamid_universe

  accepts_nested_attributes_for :profile

  acts_as_versioned
  non_versioned_columns << 'firstname'
  non_versioned_columns << 'lastname'
  non_versioned_columns << 'email'
  non_versioned_columns << 'password'
  non_versioned_columns << 'team_id'
  non_versioned_columns << 'lastvisit'
  non_versioned_columns << 'team_id'
  non_versioned_columns << 'country'
  non_versioned_columns << 'birthdate'
  non_versioned_columns << 'time_zone'
  non_versioned_columns << 'public_email'
  non_versioned_columns << 'created_at'

  def to_s
    username
  end

  def email_s
    email.gsub /@/, " (at) "
  end

  def country_s
    CountryCodeSelect::Countries::COUNTRIES.each do |c|
      if c[1] == country
        return c[0]
      end
    end
    country
  end

  def realname
    if firstname and lastname
      "#{firstname} #{lastname}"
    elsif firstname
      firstname
    elsif lastname
      lastname
    else
      ""
    end
  end

  def from
    if profile.town && profile.town.length > 0
      "#{profile.town}, #{country_s}"
    else
      "#{country_s}"
    end
  end

  def age
    return 0 unless birthdate
    a = Date.today.year - birthdate.year
    a-= 1 if Date.today < birthdate + a.years
    a
  end

  def current_layout
    profile.layout || 'default'
  end

  def joined
    created_at.strftime("%d %b %y")
  end

  def banned? type = Ban::TYPE_SITE
    Ban.first :conditions => ["expiry > UTC_TIMESTAMP() AND user_id = ? AND ban_type = ?", self.id, type]
  end

  def admin?
    groups.exists? id: Group::ADMINS
  end

  def ref?
    groups.exists? id: Group::REFEREES
  end

  def staff?
    groups.exists? id: Group::STAFF
  end

  def staff?
    groups.exists? :id => Group::STAFF
  end

  def caster?
    groups.exists? id: Group::CASTERS
  end

  # might seem redundant but allows for later extensions like forum moderators
  def moderator?
    groups.exists? id: Group::GATHER_MODERATORS
  end

  def gather_moderator?
    groups.exists? id: Group::GATHER_MODERATORS
  end

  def allowed_to_ban?
    admin? or moderator?
  end

  def gather_moderator?
    groups.exists? id: Group::GATHER_MODERATORS
  end

  def allowed_to_ban?
    admin? or gather_moderator?
  end

  def verified?
    #		created_at < DateTime.now.ago(VERIFICATION_TIME)
    true
  end

  def has_access? group
    admin? or groups.exists?(:id => group)
  end

  def new_messages
    received_personal_messages.unread_by(self) + received_team_messages.unread_by(self)
  end

  def received_messages
    received_personal_messages + received_team_messages
  end

  def sent_messages
    sent_personal_messages + sent_team_messages
  end

  def upcoming_matches
    upcoming_team_matches.ordered | upcoming_ref_matches.ordered
  end

  def past_matches
    past_team_matches.unfinished.ordered | past_ref_matches.unfinished.ordered
  end

  def unread_issues
    issues.unread_by(self)
  end

  def validate_steamid
    errors.add :steamid unless
	  steamid.nil? ||
      (m = steamid.match(/\A([01]):([01]):(\d{1,10})\Z/)) &&
      (id = m[3].to_i) &&
      id >= 1 && id <= 2147483647
  end

  def correct_steamid_universe
    if steamid.present?
      steamid[0] = "0"
    end
  end

  def validate_team
    if team and !active_teams.exists?({:id => team.id})
      errors.add :team
    end
  end

  def init_variables
    self.public_email = false
    self.time_zone = "Amsterdam"
  end

  def update_password
    self.password = Digest::MD5.hexdigest(raw_password) if raw_password and raw_password.length > 0
  end

  def send_new_password
    newpass = Verification.random_string 10
    update_attribute :password, Digest::MD5.hexdigest(newpass)
    Notifications.password(self, newpass).deliver
  end

  def can_play?
    (gathers.count(:conditions => ["gathers.status > ?", Gather::STATE_RUNNING]) > 0) or created_at < 2.years.ago
  end

  def can_create? cuser
    true
  end

  def can_update? cuser
    cuser and (self == cuser or cuser.admin?)
  end

  def can_change_name? cuser
    cuser and cuser.admin?
  end

  def can_destroy? cuser
    cuser and cuser.admin?
  end

  def self.authenticate(username, password)
    where("LOWER(username) = LOWER(?)", username).where(:password => Digest::MD5.hexdigest(password)).first
  end

  def self.get id
    id ? find(id) : ""
  end

  def self.historic steamid
    if u = User.find_by_sql(["SELECT * FROM user_versions WHERE steamid = ? ORDER BY updated_at", steamid]) and u.length > 0
      User.find u[0]['user_id']
    else
      nil
    end
  end

  def self.search(search)
    search ? where("LOWER(username) LIKE LOWER(?) OR steamid LIKE ?", "%#{search}%", "%#{search}%") : scoped
  end

  def self.refadmins
    Group.find(Group::REFEREES).users.order(:username) + Group.find(Group::ADMINS).users.order(:username)
  end

  def self.casters
    Group.find(Group::CASTERS).users.order(:username)
  end
end
