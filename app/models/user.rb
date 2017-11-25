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


require 'digest/md5'

class User < ActiveRecord::Base
  include Extra

  VERIFICATION_TIME = 604800

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

  has_many :open_issues, ->{ where(status: Issue::STATUS_OPEN) },
           :class_name => "Issue", :foreign_key => 'assigned_id'

  has_many :posted_comments, :dependent => :destroy, :class_name => "Comment"

  has_many :comments, ->{ order(created_at: :asc) },
           :class_name => "Comment", :as => :commentable, :dependent => :destroy

  has_many :teamers, :dependent => :destroy

  has_many :active_teams, ->{ where(["teamers.rank >= ? AND teams.active = ?", Teamer::RANK_MEMBER, true]) },
           :through => :teamers, :source => "team"

  has_many :active_contesters, ->{ where(active: true) },
           :through => :active_teams, :source => "contesters"

  has_many :active_contests,->{ where(status: Contest::STATUS_CLOSED) },
           :through => :active_contesters, :source => "contest"

  has_many :past_teams, ->{ group(:user_id, :team_id) },
           :through => :teamers, :source => "team"

  has_many :matchers, :dependent => :destroy
  has_many :matches, :through => :matchers
  has_many :predictions, :dependent => :destroy
  has_many :challenges_received, :through => :active_contesters, :source => "challenges_received"
  has_many :challenges_sent, :through => :active_contesters, :source => "challenges_sent"

  has_many :upcoming_team_matches, ->{ where("match_time > UTC_TIMESTAMP()") },
           :through => :active_contesters, :source => "matches"

  has_many :upcoming_ref_matches, ->{ where("match_time > UTC_TIMESTAMP()") },
           :class_name => "Match", :foreign_key => "referee_id"

  has_many :past_team_matches, ->{ where("match_time < UTC_TIMESTAMP()") },
           :through => :active_contesters, :source => "matches"

  has_many :past_ref_matches,->{ where("match_time < UTC_TIMESTAMP()") },
           :class_name => "Match", :foreign_key => "referee_id"

  has_many :received_personal_messages, :class_name => "Message", :as => "recipient", :dependent => :destroy
  has_many :sent_personal_messages, :class_name => "Message", :as => "sender", :dependent => :destroy
  has_many :sent_team_messages, :through => :active_teams, :source => :sent_messages
  has_many :match_teams, ->{ uniq }, :through => :matchers, :source => :teams

  scope :active,->{ where(banned: false) }
  scope :with_age, lambda {
    select("DATE_FORMAT(FROM_DAYS(TO_DAYS(NOW())-TO_DAYS(birthdate)), '%Y')+0 AS aged, COUNT(*) as num, username")
    .having('num > 8 AND aged > 0')
    .group('aged')
  }
  scope :country_stats, lambda {
    select("country, COUNT(*) as num")
      .where("country is not null and country != '' and country != '--'")
      .having("num > 15")
      .group("country")
      .order("num DESC")
  }
  scope :posts_stats, lambda {
    select("users.id, username, COUNT(posts.id) as num")
      .joins("LEFT JOIN posts ON posts.user_id = users.id")
      .group("users.id")
      .order("num DESC")
  }
  scope :banned, lambda {
    joins("LEFT JOIN bans ON bans.user_id = users.id AND expiry > UTC_TIMESTAMP()")
      .where("bans.id IS NOT NULL")
  }
  scope :idle, ->{ where(["lastvisit < ?", 30.minutes.ago.utc]) }
  scope :lately, ->{ where(["lastvisit > ?", 30.days.ago.utc]) }

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
    country = ISO3166::Country[self.country]
    country ? country.name : 'Earth'
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

  def received_team_messages
    Message.where(recipient_id: team_id, recipient_type: 'Team' )
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
