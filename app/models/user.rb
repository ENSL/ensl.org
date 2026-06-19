# frozen_string_literal: true

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
require 'steam_id'
require 'scrypt'
require 'securerandom'

class SteamIdValidator < ActiveModel::Validator
  def validate(record)
    return if record.steamid.nil? || record.steamid.to_s.strip.empty?

    normalized = User.normalize_steamid(record.steamid)
    if normalized
      record.steamid = normalized
    else
      record.errors.add :steamid
    end
  end
end

class User < ActiveRecord::Base
  include Extra

  VERIFICATION_TIME = 604_800

  PASSWORD_SCRYPT = 0
  PASSWORD_MD5 = 1
  PASSWORD_MD5_SCRYPT = 2

  # TODO: move this to a file
  PASSWORD_MESSAGE = \
    "Hello %s, \n" \
    "Your new password is: %s \n \n \n" \
    "(Make sure you copy all characters and no whitespace when using copy-paste)\n" \
    "(Security information: your password is stored with hash %s)\n"

  # attr_protected :id, :created_at, :updated_at, :lastvisit, :lastip, :password, :version
  attr_accessor :raw_password, :password_updated, :password_force, :fullname, :random_password

  attribute :lastvisit, :datetime, default: Time.now.utc
  attribute :password_hash, :integer, default: PASSWORD_SCRYPT

  belongs_to :team, optional: true
  has_one :profile, dependent: :destroy
  has_many :bans, dependent: :destroy
  has_many :articles, dependent: :destroy
  has_many :movies, dependent: :destroy
  has_many :servers, dependent: :destroy
  has_many :votes, dependent: :destroy
  has_many :gatherers, dependent: :destroy
  has_many :gathers, through: :gatherers
  has_many :groupers, dependent: :destroy
  has_many :posts, dependent: :destroy
  has_many :groups, through: :groupers
  has_many :shoutmsgs, dependent: :destroy
  has_many :issues, foreign_key: 'author_id', dependent: :destroy
  has_many :assigned_issues, class_name: 'Issue', foreign_key: 'assigned_id'
  has_many :posted_comments, dependent: :destroy, class_name: 'Comment'
  has_many :comments, lambda {
    order('created_at ASC')
  }, class_name: 'Comment', as: :commentable, dependent: :destroy
  has_many :teamers, dependent: :destroy
  has_many :active_teams, -> { where('teamers.rank >= ? AND teams.active = ?', Teamer::RANK_MEMBER, true) }, \
           through: :teamers, source: 'team'
  has_many :lead_teams, -> { where('teamers.rank >= ? AND teams.active = ?', Teamer::RANK_DEPUTEE, true) }, \
           through: :teamers, source: 'team'
  has_many :active_contesters, -> { where('contesters.active = ?', true) }, \
           through: :active_teams, source: 'contesters'
  has_many :active_contests, -> { where('contests.status != ?', Contest::STATUS_CLOSED) }, \
           through: :active_contesters, source: 'contest'
  has_many :matchers, dependent: :destroy
  has_many :matches, through: :matchers
  has_many :predictions, dependent: :destroy
  has_many :challenges_received, through: :active_contesters, source: 'challenges_received'
  has_many :challenges_sent, through: :active_contesters, source: 'challenges_sent'
  has_many :upcoming_team_matches, -> { where('match_time > UTC_TIMESTAMP()') },
           through: :active_teams, source: 'matches'
  has_many :upcoming_ref_matches, -> { where('match_time > UTC_TIMESTAMP()') },
           class_name: 'Match', foreign_key: 'referee_id'
  has_many :past_team_matches, -> { where('match_time < UTC_TIMESTAMP()') },
           through: :active_contesters, source: 'matches'
  has_many :past_ref_matches, -> { where('match_time < UTC_TIMESTAMP()') },
           class_name: 'Match', foreign_key: 'referee_id'
  has_many :received_personal_messages, class_name: 'Message', as: 'recipient', dependent: :destroy
  has_many :sent_personal_messages, class_name: 'Message', as: 'sender', dependent: :destroy
  has_many :sent_team_messages, through: :active_teams, source: :sent_messages
  has_many :match_teams, -> { group('teams.id') }, through: :matchers, source: :teams

  scope :active, -> { where(banned: false) }
  scope :with_age, lambda {
    select('TIMESTAMPDIFF(YEAR, birthdate, CURDATE()) AS aged, COUNT(*) AS num')
      .where.not(birthdate: nil)
      .group('aged')
      .having('COUNT(*) > 8 AND aged > 0')
  }
  scope :country_stats, lambda {
    select('country, COUNT(*) as num')
      .where("country is not null and country != '' and country != '--'")
      .group('country')
      .having('num > 15')
      .order('num DESC')
  }
  scope :posts_stats, lambda { |_ignored|
    select('users.id, username, COUNT(posts.id) as num')
      .joins('LEFT JOIN posts ON posts.user_id = users.id')
      .group('users.id')
      .order('num DESC')
  }
  scope :banned, lambda {
    joins('LEFT JOIN bans ON bans.user_id = users.id AND expiry > UTC_TIMESTAMP()')
      .where('bans.id IS NOT NULL')
  }
  scope :idle, lambda {
    where('lastvisit < ?', 30.minutes.ago.utc)
  }
  scope :lately, lambda {
    where('lastvisit > ?', 30.days.ago.utc)
  }

  before_validation :update_password

  validates_uniqueness_of :username, :email, case_sensitive: false
  validates_presence_of :email
  validate :steamid_uniqueness
  validates_length_of :firstname, in: 1..15, allow_blank: true
  validates_length_of :lastname, in: 1..25, allow_blank: true
  validates_length_of :username, in: 1..30
  validates_format_of :username, with: /\A[A-Za-z0-9_\-+]{1,30}\Z/
  validates_presence_of :raw_password, on: :create
  validates_length_of :email, maximum: 50
  validates_format_of :email, with: /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i
  validates_length_of :steamid, maximum: 30
  validates_with SteamIdValidator
  # validates_format_of :steamid, :with => /\A(STEAM_)?[0-5]:[01]:\d+\Z/
  validates_length_of :time_zone, maximum: 100, allow_blank: true, allow_nil: true
  validates_inclusion_of [:public_email], in: [true, false], allow_nil: true
  # validates_inclusion_of :password_hash, in: => [User::PASSWORD_SCRYPT, User::PASSWORD_MD5, User::PASSWORD_MD5_SCRYPT]
  validate :validate_team

  # Allow existing duplicate steamids in DB to continue working.
  # Enforce uniqueness when there are no prior duplicates; if duplicates already
  # exist for a given steamid we skip the uniqueness error to avoid blocking
  # logins/creation for records that match an existing (broken) state.
  # FIXME: this is a temporary measure until all duplicates are resolved.
  def steamid_uniqueness
    return if steamid.nil? || steamid.to_s.strip.empty?

    # If updating and steamid didn't change, skip uniqueness check.
    return true unless steamid_changed?

    existing = User.where('LOWER(steamid) = ?', steamid.to_s.downcase).where.not(id: id)
    return true if existing.nil? || existing.count.zero?

    errors.add(:steamid, :taken)
  end

  before_validation :set_name
  before_validation :init_variables, on: :create
  after_create :create_profile
  after_create :send_new_password, if: proc { random_password == true }
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

  def self.normalize_steamid(value)
    return nil if value.nil?

    str = value.to_s.strip
    return nil if str.empty?

    # Allow legacy format without STEAM_ prefix for convenience
    str = "STEAM_#{str}" if str.match?(/\A[01]:[01]:\d+\Z/)

    sid = SteamID.from_string(str)
    return nil unless sid
    return nil if sid.respond_to?(:valid?) && !sid.valid?

    legacy = sid.id.to_s
    legacy = legacy.sub(/\ASTEAM_/, '')
    return nil unless legacy.match?(/\A[01]:[01]:\d+\Z/)

    legacy
  rescue StandardError
    nil
  end

  def set_name
    return unless fullname

    if fullname.include?(' ')
      # TODO: check this
      self.firstname = fullname.match(/(?:^|(?:\.\s))(\w+)/)[1]
      self.lastname = fullname.match(/\s(\w+)$/)[1]
    else
      self.firstname = fullname
    end
  end

  def password_hash_s
    case password_hash
    when User::PASSWORD_MD5
      'MD5'
    when User::PASSWORD_SCRYPT
      'Scrypt'
    when User::PASSWORD_MD5_SCRYPT
      'Scrypt+MD5'
    end
  end

  def email_s
    email.gsub(/@/, ' (at) ')
  end

  def country_s
    country_object = ISO3166::Country[country]
    if country_object
      country_object.translations[I18n.locale.to_s] || country_object.name
    else
      'Unknown'
    end
  end

  def realname
    if firstname && lastname
      "#{firstname} #{lastname}"
    elsif firstname
      firstname
    elsif lastname
      lastname
    else
      ''
    end
  end

  def from
    if profile.town&.length&.positive?
      "#{profile.town}, #{country_s}"
    else
      country_s.to_s
    end
  end

  def age
    return 0 unless birthdate

    a = Time.zone.today.year - birthdate.year
    a -= 1 if Time.zone.today < birthdate + a.years
    a
  end

  def idle
    return '0 m' if lastvisit.nil?

    minutes = ((Time.now.utc - lastvisit.to_time.utc) / 60).floor
    format('%d m', minutes)
  end

  def current_layout
    profile.layout || 'default'
  end

  def joined
    created_at.strftime('%d %b %y')
  end

  def current_teamer
    team ? teamers.active.of_team(team).first : nil
  end

  def preformat
    self.email = '' if email&.include?('@ensl.org')
  end

  def banned?(type = Ban::TYPE_SITE)
    bans.effective.where(ban_type: type).count.positive?
  end

  def admin?
    group_cached?(Group::ADMINS)
  end

  def ref?
    group_cached?(Group::REFEREES)
  end

  def staff?
    group_cached?(Group::STAFF)
  end

  def caster?
    group_cached?(Group::CASTERS)
  end

  # might seem redundant but allows for later extensions like forum moderators
  def moderator?
    group_cached?(Group::GATHER_MODERATORS)
  end

  def gather_moderator?
    group_cached?(Group::GATHER_MODERATORS)
  end

  def contributor?
    group_cached?(Group::CONTRIBUTORS)
  end

  def allowed_to_ban?
    admin? or moderator?
  end

  def verified?
    true
  end

  def access?(groups)
    admin? or group_cached?(groups)
  end

  private

  # Cache membership checks for the lifetime of this model instance to
  # avoid repeated DB queries when role checks are called frequently from views.
  def group_cached?(group_id)
    @group_membership_cache ||= {}
    return @group_membership_cache[group_id] unless @group_membership_cache[group_id].nil?

    @group_membership_cache[group_id] = groups.exists?(id: group_id)
  end

  public

  def new_messages
    received_personal_messages.union(received_team_messages).unread_by(self)
  end

  def received_messages
    received_personal_messages.union(received_team_messages)
  end

  def received_team_messages
    Message.where(recipient_id: team_id, recipient_type: 'Team')
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

  def duplicates
    # TODO: user arel
    User.where('lower(username) = ? AND users.id != ?', username.downcase, id)
  end

  def correct_steamid_universe
    steamid[0] = '0' if steamid.present?
  end

  # FIXME: if team has been removed
  def validate_team
    return unless team && !active_teams.exists?({ id: team.id })

    # Attempts to fix team, gracefully
    self.team = nil
    save
    errors.add :team
  end

  def init_variables
    self.public_email = false
    self.time_zone = 'Amsterdam'
    generate_password if !raw_password && new_record?
    build_profile unless profile&.present?
    # Email is required; do not auto-fill when blank.
  end

  def generate_password
    self.raw_password = SecureRandom.alphanumeric(24)
    self.password_hash = User::PASSWORD_SCRYPT
    self.random_password = true
  end

  def create_profile
    return unless profile

    profile.user_id = id
    profile.save
  end

  # NOTE: function does not call save
  # Maybe it should return to not waste save?
  def update_password
    # Standard logic for saving password
    if raw_password&.length&.positive?
      # Allow old hash too
      if (password_hash == User::PASSWORD_MD5) && password_force
        self.password = Digest::MD5.hexdigest(raw_password)
      else
        self.password_hash = User::PASSWORD_SCRYPT
        self.password = SCrypt::Password.create(raw_password)
      end
    # Update MD5 to MD5+Scrypt
    elsif (password_hash == User::PASSWORD_MD5) && !password_force
      # Scrypt(Md5(passsword))
      self.password_hash = User::PASSWORD_MD5_SCRYPT
      self.password = SCrypt::Password.create(password)
    end
  end

  # This serves multiple functions
  def send_new_password
    generate_password unless raw_password&.length.to_i.positive?
    save!

    # TODO: consider moving these two to callbacks
    send_password_message
    Notifications.password(self, raw_password).deliver
  end

  def send_password_message(text = User::PASSWORD_MESSAGE)
    msg = Message.new
    msg.title = 'New password for ENSL website'
    msg.text = format(text, username, raw_password, password_hash_s)
    msg.sender_type = 'System'
    msg.recipient_type = 'User'
    msg.recipient = self
    msg.save
  end

  def can_play?
    gathers.where('gathers.status > ?', Gather::STATE_RUNNING).count.positive? or created_at < 2.years.ago
  end

  def can_create?(_cuser)
    true
  end

  def fix_attributes
    return unless errors[:username]

    i = 2
    loop do
      new_username = "#{username}#{i}"
      i += 1
      if User.where(username: new_username).count.zero? || (i > 50)
        self.username = new_username
        break
      end
    end

    # Email is required and should be provided by user; do not auto-fill here.
  end

  def can_update?(cuser)
    cuser and (self == cuser or cuser.admin?)
  end

  def can_change_name?(cuser)
    cuser&.admin?
  end

  def can_destroy?(cuser)
    cuser&.admin?
  end

  def self.authenticate(login)
    username = login[:username].to_s
    user = where('BINARY username = ?', username).first
    unless user
      Rails.logger.info("Auth failed: username not found username=#{username.inspect}")
      return nil
    end

    case user.password_hash
    when User::PASSWORD_SCRYPT
      # FIXME: If exception occurs here, user cannot log in
      begin
        pass = SCrypt::Password.new(user.password)
      rescue StandardError
        Rails.logger.error("Auth failed: invalid scrypt hash user_id=#{user.id} username=#{user.username}")
        return nil
      end
      return user if pass == login[:password]

      Rails.logger.info("Auth failed: password mismatch user_id=#{user.id} username=#{user.username} hash=scrypt")
    when User::PASSWORD_MD5_SCRYPT
      pass = SCrypt::Password.new(user.password)
      # Match to Scrypt(Md5(password))
      if pass == Digest::MD5.hexdigest(login[:password])
        user.raw_password = login[:password]
        user.update_password
        user.save!(validate: false)
        return user
      end
      Rails.logger.info("Auth failed: password mismatch user_id=#{user.id} username=#{user.username} hash=md5_scrypt")
    # when User::PASSWORD_MD5
    else
      if user.password == Digest::MD5.hexdigest(login[:password])
        user.raw_password = login[:password]
        user.update_password
        user.save!(validate: false)
        return user
      end
      Rails.logger.info("Auth failed: password mismatch user_id=#{user.id} username=#{user.username} hash=md5")
    end
    return nil
    # TODO: controller needs to handle this
    # rescue Exception => ex
    #  user.errors.add(:password, "%s (%s)" % [I18n.t(:password_corrupt), ex.class.to_s])
    #  return nil
    nil
  end

  def self.get(id)
    id ? User.find(id) : ''
  end

  def self.historic(steamid)
    if (u = User.find_by_sql(['SELECT * FROM user_versions WHERE steamid = ? ORDER BY updated_at',
                              steamid])) && u.length.positive?
      User.find u[0]['user_id']
    end
  end

  def self.search(search)
    search ? where('LOWER(username) LIKE LOWER(?) OR steamid LIKE ?', "%#{search}%", "%#{search}%") : all
  end

  def self.refadmins
    Group.find(Group::REFEREES).users.order(:username) + Group.find(Group::ADMINS).users.order(:username)
  end

  def self.casters
    Group.find(Group::CASTERS).users.order(:username)
  end

  def self.params(params, cuser, operation)
    # Explicitly permit nested profile attributes
    profile_allowed = (
      Profile.column_names.map(&:to_sym) +
      %i[notify_news notify_articles notify_movies notify_gather notify_own_match
         notify_any_match notify_challenge notify_pms avatar _destroy]
    ).uniq

    allowed = [
      :raw_password, :firstname, :lastname, :email, :steamid, :country,
      :birthdate, :timezone, :public_email, :filter, :time_zone, :team_id,
      { profile_attributes: profile_allowed }
    ]
    allowed << :username if cuser&.admin? || operation == 'create'

    params.require(:user).permit(*allowed)
  end

  def self.find_or_build(auth_hash, lastip)
    return nil unless auth_hash&.include?(:provider)

    case auth_hash[:provider]
    when 'steam'
      return nil unless auth_hash&.include?(:uid)

      steamid = User.normalize_steamid(auth_hash[:uid])
      user = User.where('LOWER(steamid) = LOWER(?)', steamid).first
      unless user
        user = User.new(username: auth_hash[:info][:nickname], lastip: lastip, fullname: auth_hash[:info][:name],
                        steamid: steamid)
        user.fix_attributes
        user.build_profile
        # TODO: user make valid by force
        # user.profile.country
        # get profile picture, :image
        # This really shouldn't fail.
      end
      return user
    end
    nil
  end
end
