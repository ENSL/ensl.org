# == Schema Information
#
# Table name: bans
#
#  id         :integer          not null, primary key
#  addr       :string(255)
#  ban_type   :integer
#  expiry     :datetime
#  ip         :string(255)
#  reason     :string(255)
#  steamid    :string(255)
#  created_at :datetime
#  updated_at :datetime
#  creator_id :integer
#  server_id  :integer
#  user_id    :integer
#
# Indexes
#
#  index_bans_on_creator_id  (creator_id)
#  index_bans_on_server_id   (server_id)
#  index_bans_on_user_id     (user_id)
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

  #attr_protected :id, :created_at, :updated_at
  attr_accessor :len, :user_name

  scope :ordered,  -> {order("created_at DESC")}
  scope :effective, -> {where("expiry > UTC_TIMESTAMP()")}
  scope :ineffective, -> {where("expiry < UTC_TIMESTAMP()")}

  before_validation :check_user

  validate :validate_type
  validate :validate_ventban
  validate :validate_permission
  validates :steamid, length: {maximum: 14}, format: /\A0:[01]:[0-9]{1,10}\Z/, allow_blank: true
  validates :addr, format: /\A([0-9]{1,3}\.){3}[0-9]{1,3}:?[0-9]{0,5}\z/, allow_blank: true
  validates :reason, length: {maximum: 255}, allow_blank: true

  belongs_to :user
  belongs_to :server

  belongs_to :creator, foreign_key: 'creator_id', class_name: 'User'

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

  def validate_permission
    unless creator.nil? or creator.admin? or (creator.gather_moderator? and self.ban_type == TYPE_GATHER)
      errors.add :ban_type, 'Gather Moderators can only create gather bans'
    end
  end

  def check_user
    if user_name
      self.user = User.find_by_username(user_name)
    else
      self.user = User.where(steamid: steamid).first
      self.server = Server.where("CONCAT(ip, ':', port) = ?", addr).first
    end
  end

  def can_create? cuser
    cuser and cuser.allowed_to_ban?
  end

  def can_update? cuser
    cuser and (cuser.admin? or (self.creator == cuser and cuser.allowed_to_ban?))
  end

  def can_destroy? cuser
    cuser and (cuser.admin? or (self.creator == cuser and cuser.allowed_to_ban?))
  end

  def self.params params, cuser
    params.require(:ban).permit(:steamid, :user_id, :addr, :server_id, :expiry, :reason, :ban_type, :ip)
  end
end
