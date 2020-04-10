# == Schema Information
#
# Table name: users
#
#  id            :integer          not null, primary key
#  birthdate     :date
#  country       :string(255)
#  email         :string(255)
#  firstname     :string(255)
#  lastip        :string(255)
#  lastname      :string(255)
#  lastvisit     :datetime
#  password      :string(255)
#  password_hash :integer          default(0)
#  public_email  :boolean          default(FALSE), not null
#  steamid       :string(255)
#  time_zone     :string(255)
#  username      :string(255)
#  version       :integer
#  created_at    :datetime
#  updated_at    :datetime
#  team_id       :integer
#
# Indexes
#
#  index_users_on_lastvisit  (lastvisit)
#  index_users_on_team_id    (team_id)
#

require 'digest/md5'
require 'steamid'
require "scrypt"
require 'securerandom'

class SteamIdValidator < ActiveModel::Validator
  def validate(record)
    record.errors.add :steamid unless \
      record.steamid.nil? ||
        (m = record.steamid.match(/\A([01]):([01]):(\d{1,10})\Z/)) &&
        (id = m[3].to_i) &&
        id >= 1 && id <= 2147483647
  end
end

class User < ActiveRecord::Base
  include Extra

  VERIFICATION_TIME = 604800

  PASSWORD_SCRYPT = 0
  PASSWORD_MD5 = 1
  PASSWORD_MD5_SCRYPT = 2

  #attr_protected :id, :created_at, :updated_at, :lastvisit, :lastip, :password, :version
  attr_accessor :raw_password, :password_updated, :password_force, :fullname

  attribute :lastvisit, :datetime, default: Time.now.utc
  attribute :password_hash, :integer, default: PASSWORD_SCRYPT

  belongs_to :team, :optional => true
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
  has_many :assigned_issues, :class_name => "Issue", :foreign_key => "assigned_id"
  has_many :posted_comments, :dependent => :destroy, :class_name => "Comment"
  has_many :comments, -> { order("created_at ASC") }, :class_name => "Comment", :as => :commentable, :dependent => :destroy
  has_many :teamers, :dependent => :destroy
  has_many :active_teams, -> { where("teamers.rank >= ? AND teams.active = ?", Teamer::RANK_MEMBER, true) }, \
           :through => :teamers, :source => "team"
  has_many :lead_teams, -> { where("teamers.rank >= ? AND teams.active = ?", Teamer::RANK_DEPUTEE, true) }, \
           :through => :teamers, :source => "team"
  has_many :active_contesters, -> { where("contesters.active = ?", true) }, \
           :through => :active_teams, :source => "contesters"
  has_many :active_contests, -> { where("contests.status != ?", Contest::STATUS_CLOSED) }, \
           :through => :active_contesters, :source => "contest"
  has_many :matchers, :dependent => :destroy
  has_many :matches, :through => :matchers
  has_many :predictions, :dependent => :destroy
  has_many :challenges_received, :through => :active_contesters, :source => "challenges_received"
  has_many :challenges_sent, :through => :active_contesters, :source => "challenges_sent"
  has_many :upcoming_team_matches, -> { where("match_time > UTC_TIMESTAMP()") },
           :through => :active_teams, :source => "matches"
  has_many :upcoming_ref_matches, -> { where("match_time > UTC_TIMESTAMP()") },
           :class_name => "Match", :foreign_key => "referee_id"
  has_many :past_team_matches, -> { where("match_time < UTC_TIMESTAMP()") },
           :through => :active_contesters, :source => "matches"
  has_many :past_ref_matches, -> { where("match_time < UTC_TIMESTAMP()") },
           :class_name => "Match", :foreign_key => "referee_id"
  has_many :received_personal_messages, :class_name => "Message", :as => "recipient", :dependent => :destroy
  has_many :sent_personal_messages, :class_name => "Message", :as => "sender", :dependent => :destroy
  has_many :sent_team_messages, :through => :active_teams, :source => :sent_messages
  has_many :match_teams, :through => :matchers, :source => :teams

  scope :active, -> { where(banned: false) }
  scope :with_age, -> {
      where("DATE_FORMAT(FROM_DAYS(TO_DAYS(NOW())-TO_DAYS(birthdate)), '%Y')+0 AS aged, COUNT(*) as num, username")
     .group("aged")
     .having("num > 8 AND aged > 0") }
  scope :country_stats, -> {
     select("country, COUNT(*) as num")
     .where("country is not null and country != '' and country != '--'")
     .group("country")
     .having("num > 15")
     .order("num DESC") }
  scope :posts_stats, -> {
     select("users.id, username, COUNT(posts.id) as num")
     .joins("LEFT JOIN posts ON posts.user_id = users.id")
     .group("users.id")
     .order("num DESC") }
  scope :banned, -> {
      joins("LEFT JOIN bans ON bans.user_id = users.id AND expiry > UTC_TIMESTAMP()")
      .where("bans.id IS NOT NULL") }
  scope :idle, -> {
      where("lastvisit < ?", 30.minutes.ago.utc) }
  scope :lately, -> {
      where("lastvisit > ?", 30.days.ago.utc) }

  before_validation :update_password

  validates_uniqueness_of :username, :email, :steamid
  validates_length_of :firstname, :in => 1..15, :allow_blank => true
  validates_length_of :lastname, :in => 1..25, :allow_blank => true
  validates_length_of :username, :in => 1..30
  validates_format_of :username, :with => /\A[A-Za-z0-9_\-\+]{1,30}\Z/
  validates_presence_of :raw_password, :on => :create
  validates_length_of :email, :maximum => 50
  validates_format_of :email, :with => /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i
  validates_length_of :steamid, :maximum => 30
  validates_with SteamIdValidator
  # validates_format_of :steamid, :with => /\A(STEAM_)?[0-5]:[01]:\d+\Z/
  validates_length_of :time_zone, :maximum => 100, :allow_blank => true, :allow_nil => true
  validates_inclusion_of [:public_email], :in => [true, false], :allow_nil => true
  # validates_inclusion_of :password_hash, in: => [User::PASSWORD_SCRYPT, User::PASSWORD_MD5, User::PASSWORD_MD5_SCRYPT]
  validate :validate_team

  before_validation :set_name
  before_create :init_variables
  after_create :create_profile
  before_save :correct_steamid_universe

  accepts_nested_attributes_for :profile

  acts_as_reader

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
  non_versioned_columns << 'password_hash'
  non_versioned_columns << 'created_at'

  def to_s
    username
  end

  def set_name
    return unless fullname
    if fullname.include?(" ")
      # TODO: check this
      self.firstname = fullname.match(/(?:^|(?:\.\s))(\w+)/)[1]
      self.surname = fullname.match(/\s(\w+)$/)[1]
    else
      self.firstname = fullname
    end
  end

  def password_hash_s
    case self.password_hash
    when User::PASSWORD_MD5
      "MD5"
    when User::PASSWORD_SCRYPT
      "Scrypt"
    when User::PASSWORD_MD5_SCRYPT
      "Scrypt+MD5"
    else
    end
  end

  def email_s
    email.gsub /@/, " (at) "
  end

  def country_s
    country_object = ISO3166::Country[country]
    if country_object
      country_object.translations[I18n.locale.to_s] || country_object.name
    else
      "Unknown"
    end
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
    a = Time.zone.today.year - birthdate.year
    a-= 1 if Time.zone.today < birthdate + a.years
    a
  end

  def idle
    "%d m" % [TimeDifference.between(Time.now.utc, lastvisit).in_minutes.floor]
  end

  def current_layout
    profile.layout || 'default'
  end

  def joined
    created_at.strftime("%d %b %y")
  end

  def current_teamer
    team ? teamers.active.of_team(team).first : nil
  end

  def banned? type = Ban::TYPE_SITE
    bans.effective.where(ban_type: type).count > 0
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

  def contributor?
    groups.exists? id: Group::CONTRIBUTORS
  end

  def allowed_to_ban?
    admin? or moderator?
  end

  def verified?
    true
  end

  def has_access? groups
    admin? or groups.exists?(:id => group)
  end

  def new_messages
    received_personal_messages.union(received_team_messages).unread_by(self)
  end

  def received_messages
    received_personal_messages.union(received_team_messages)
  end

  def received_team_messages
    Message.where(recipient_id: team_id, recipient_type: 'Team' )
  end

  def sent_messages
    sent_personal_messages.union(sent_team_messages)
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

  def correct_steamid_universe
    if steamid.present?
      steamid[0] = "0"
    end
  end

  # FIXME: if team has been removed
  def validate_team
    if team and !active_teams.exists?({:id => team.id})
      self.team = nil
      self.save!
      errors.add :team
    end
  end

  def init_variables
    self.public_email = false
    self.time_zone = "Amsterdam"
    self.raw_password = SecureRandom.base64(32) unless raw_password and new_record?
    self.profile = profile.build unless profile&.present?
  end

  def create_profile
    if profile
      profile.save
    end
  end

  # NOTE: function does not call save
  # Maybe it should return to not waste save?
  def update_password
    # Standard logic for saving password
    if raw_password and raw_password.length > 0
      # Allow old hash too
      if password_hash == User::PASSWORD_MD5 and password_force
        self.password = Digest::MD5.hexdigest(raw_password)
      else
        self.password_hash = User::PASSWORD_SCRYPT
        self.password = SCrypt::Password.create(raw_password)
      end
    # Update MD5 to MD5+Scrypt
    elsif password_hash == User::PASSWORD_MD5 and !password_force
      # Scrypt(Md5(passsword))
      self.password_hash = User::PASSWORD_MD5_SCRYPT
      self.password = SCrypt::Password.create(password)
    end
  end

  def send_new_password
    newpass = Verification.random_string 10
    update_attribute :password, Digest::MD5.hexdigest(newpass)
    Notifications.password(self, newpass).deliver
  end

  def can_play?
    (gathers.where("gathers.status > ?", Gather::STATE_RUNNING).count > 0) or created_at < 2.years.ago
  end

  def can_create? cuser
    true
  end

  def fix_attributes
    if errors[:username]
      i = 2
      loop do
        new_username = "%s%d" % [username, i]
        i+=1
        break if User.find_by_username(new_username).count == 0 or i > 50
      end
      self.username = new_username
    end
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

  def self.authenticate(login)
    if (user = where("LOWER(username) = LOWER(?)", login[:username]).first)
      begin
        case user.password_hash
        when User::PASSWORD_SCRYPT
          # FIXME: If exception occurs here, user cannot log in
          pass = SCrypt::Password.new(user.password)
          return user if pass == login[:password]
        when User::PASSWORD_MD5_SCRYPT
          pass = SCrypt::Password.new(user.password)
          # Match to Scrypt(Md5(password))
          if pass == Digest::MD5.hexdigest(login[:password])
            user.raw_password = login[:password]
            user.update_password
            user.save!
            return user
          end
        # when User::PASSWORD_MD5
        else
          if user.password == Digest::MD5.hexdigest(login[:password])
            user.raw_password = login[:password]
            user.update_password
            user.save!
            return user
          end
        end
      # TODO: controller needs to handle this
      #rescue Exception => ex
      #  user.errors.add(:password, "%s (%s)" % [I18n.t(:password_corrupt), ex.class.to_s])
      #  return nil
      end
    end
    return nil
  end

  def self.get(id)
    id ? User.find(id) : ""
  end

  def self.historic steamid
    if u = User.find_by_sql(["SELECT * FROM user_versions WHERE steamid = ? ORDER BY updated_at", steamid]) and u.length > 0
      User.find u[0]['user_id']
    else
      nil
    end
  end

  def self.search(search)
    search ? where("LOWER(username) LIKE LOWER(?) OR steamid LIKE ?", "%#{search}%", "%#{search}%") : all
  end

  def self.refadmins
    Group.find(Group::REFEREES).users.order(:username) + Group.find(Group::ADMINS).users.order(:username)
  end

  def self.casters
    Group.find(Group::CASTERS).users.order(:username)
  end

  def self.params(params, cuser, operation)
    profile_attrs ||= cuser.profile.attributes.keys - ["id", "created_at", "updated_at"] if cuser
    allowed = [:raw_password, :firstname, :lastname, :email, :steamid, :country, \
               :birthdate, :timezone, :public_email, :filter, :time_zone, :team_id, \
               profile_attributes: [profile_attrs]]
    allowed << :username if cuser&.admin? || operation == 'create'
    params.require(:user).permit(*allowed)
  end

  def self.focfah(auth_hash, lastip)
    return nil unless auth_hash&.include?(:provider)
    byebug
    case auth_hash[:provider]
    when 'steam'
      return nil unless auth_hash&.include?(:uid)
      steamid = SteamID::from_steamID64(auth_hash[:uid])
      user = User.where("LOWER(steamid) = LOWER(?)", steamid).first
      unless user
        user = User.new(username: auth_hash[:info][:nickname], lastip: lastip, fullname: auth_hash[:info][:name], steamid: steamid)
        user.fix_attributes
        # TODO: user make valid by force
        # user.profile.country
        # get profile picture, :image
        # This really shouldn't fail.
        user.save!
      end
      return user
    end
    return nil
  end
end