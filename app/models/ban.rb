# == Schema Information
#
# Table name: bans
#
#  id         :integer          not null, primary key
#  steamid    :string(255)
#  user_id    :integer
#  addr       :string(255)
#  server_id  :integer
#  expiry     :datetime
#  reason     :string(255)
#  created_at :datetime
#  updated_at :datetime
#  ban_type   :integer
#  ip         :string(255)
#

class Ban < ActiveRecord::Base
  include Extra

  TYPE_SITE = 0
  TYPE_MUTE = 1
  TYPE_LEAGUE = 2
  TYPE_SERVER = 3
  TYPE_VENT = 4
  TYPE_GATHER = 5
  VENT_BANS = "tmp/bans.txt"

  attr_protected :id, :created_at, :updated_at
  attr_accessor :len, :user_name

  scope :ordered, order: "created_at DESC"
  scope :effective, conditions: "expiry > UTC_TIMESTAMP()"
  scope :ineffective, conditions: "expiry < UTC_TIMESTAMP()"

  validate :validate_type
  validate :validate_ventban
  validates_format_of :steamid, with: /\A([0-9]{1,10}:){2}[0-9]{1,10}\Z/, allow_blank: true
  validates_format_of :addr, with: /\A([0-9]{1,3}\.){3}[0-9]{1,3}:?[0-9]{0,5}\z/, allow_blank: true
  validates_length_of :reason, maximum: 255, allow_nil: true, allow_blank: true

  before_validation :check_user

  belongs_to :user
  belongs_to :server

  def color
    expiry.past? ? "green" : "red"
  end

  def types
    {TYPE_SITE => "Website Logon",
     TYPE_MUTE => "Commenting",
     TYPE_LEAGUE => "Contests",
     TYPE_SERVER => "NS Servers",
     TYPE_VENT => "Ventrilo",
     TYPE_GATHER => "Gather"}
  end

  def validate_type
    errors.add :ban_type, I18n.t(:invalid_ban_type) unless types.include? ban_type
  end

  def validate_ventban
    if ban_type == TYPE_VENT and !ip.match(/\A([0-9]{1,3}\.){3}[0-9]{1,3}\z/)
      errors.add :ip, I18n.t(:ventrilos_ip_ban)
    end
  end

  def check_user
    if user_name
      self.user = User.find_by_username(user_name)
    else
      self.user = User.first(conditions: { steamid: steamid })
      self.server = Server.first(conditions: ["CONCAT(ip, ':', port) = ?", addr])
    end
  end

  def can_create? cuser
    cuser and cuser.admin?
  end

  def can_update? cuser
    cuser and cuser.admin?
  end

  def can_destroy? cuser
    cuser and cuser.admin?
  end

  def self.refresh
    #file = File.new(VENT_BANS, "w")
    #Ban.all(:conditions => ["ban_type = ? AND expiry > UTC_TIMESTAMP()", TYPE_VENT]).each do |ban|
    #	file.write "#{ban.ip},,,"
    #end
    #file.close
  end
end
