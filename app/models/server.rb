# == Schema Information
#
# Table name: servers
#
#  id              :integer          not null, primary key
#  name            :string(255)
#  description     :string(255)
#  dns             :string(255)
#  ip              :string(255)
#  port            :string(255)
#  rcon            :string(255)
#  password        :string(255)
#  irc             :string(255)
#  user_id         :integer
#  official        :boolean
#  created_at      :datetime
#  updated_at      :datetime
#  map             :string(255)
#  players         :integer
#  max_players     :integer
#  ping            :string(255)
#  version         :integer
#  domain          :integer          default(0), not null
#  reservation     :string(255)
#  recording       :string(255)
#  idle            :datetime
#  default_id      :integer
#  active          :boolean          default(TRUE), not null
#  recordable_type :string(255)
#  recordable_id   :integer
#  category_id     :integer
#

require "yaml"

class Server < ActiveRecord::Base
  include Extra

  DOMAIN_HLDS = 0
  DOMAIN_HLTV = 1
  DOMAIN_NS2 = 2

  attr_accessor :pwd
  attr_protected :id, :user_id, :updated_at, :created_at, :map, :players, :maxplayers, :ping, :version

  validates_length_of [:name, :dns,], :in => 1..30
  validates_length_of [:rcon, :password, :irc], :maximum => 30, :allow_blank => true
  validates_length_of :description, :maximum => 255, :allow_blank => true
  validates_format_of :ip, :with => /\A[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\z/
  validates_format_of :port, :with => /\A[0-9]{1,5}\z/
  validates_format_of :reservation, :with => /\A[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}:[0-9]{1,5}\z/, :allow_nil => true
  validates_format_of :pwd, :with => /\A[A-Za-z0-9_\-]*\z/, :allow_nil => true

  scope :ordered, :order => "name"
  scope :hlds, :conditions => ["domain = ?", DOMAIN_HLDS]
  scope :ns2, :conditions => ["domain = ?", DOMAIN_NS2]
  scope :hltvs, :conditions => ["domain = ?", DOMAIN_HLTV]
  scope :active, :conditions => "active = 1"
  scope :with_players, :conditions => "players > 0"
  scope :reserved, :conditions => "reservation IS NOT NULL"
  scope :unreserved_now, :conditions => "reservation IS NULL"
  scope :unreserved_hltv_around,
    lambda { |time| {
    :select => "servers.*",
    :joins => "LEFT JOIN matches ON servers.id = matches.hltv_id
  AND match_time > '#{(time.ago(Match::MATCH_LENGTH).utc).strftime("%Y-%m-%d %H:%M:%S")}'
  AND match_time < '#{(time.ago(-Match::MATCH_LENGTH).utc).strftime("%Y-%m-%d %H:%M:%S")}'",
    :conditions => "matches.hltv_id IS NULL"} }

  has_many :logs
  has_many :matches
  has_many :challenges
  belongs_to :user
  belongs_to :recordable, :polymorphic => true

  before_create :set_category

  acts_as_versioned
  non_versioned_columns << 'name'
  non_versioned_columns << 'description'
  non_versioned_columns << 'dns'
  non_versioned_columns << 'ip'
  non_versioned_columns << 'port'
  non_versioned_columns << 'rcon'
  non_versioned_columns << 'password'
  non_versioned_columns << 'irc'
  non_versioned_columns << 'user_id'
  non_versioned_columns << 'official'
  non_versioned_columns << 'domain'
  non_versioned_columns << 'reservation'
  non_versioned_columns << 'recording'
  non_versioned_columns << 'idle'
  non_versioned_columns << 'default_id'
  non_versioned_columns << 'active'
  non_versioned_columns << 'recordable_type'
  non_versioned_columns << 'recordable_id'

  def domains
    {DOMAIN_HLTV => "HLTV", DOMAIN_HLDS => "NS Server", DOMAIN_NS2 => "NS2 Server"}
  end

  def to_s
    name
  end

  def addr
    ip + ":" + port.to_s
  end

  def set_category
    self.category_id = (domain == DOMAIN_NS2 ? 45 : 44 )
  end

  def is_free time
    challenges.around(time).pending.count == 0 and matches.around(time).count == 0
  end

  def can_create? cuser
    cuser
  end

  def can_update? cuser
    cuser and cuser.admin? or user == cuser
  end

  def can_destroy? cuser
    cuser and cuser.admin?
  end

  def self.move addr, newaddr, newpwd
    self.hltvs.all(:conditions => {:reservation => addr}).each do |hltv|
      hltv.reservation = newaddr
      hltv.pwd = newpwd
      hltv.save!
    end
  end

  def self.stop addr
    self.hltvs.all(:conditions => {:reservation => addr}).each do |hltv|
      hltv.reservation = nil
      hltv.save!
    end
  end
end
