# frozen_string_literal: true

# == Schema Information
#
# Table name: servers
#
#  id              :integer          not null, primary key
#  active          :boolean          default(TRUE), not null
#  description     :string(255)
#  dns             :string(255)
#  domain          :integer          default(0), not null
#  idle            :datetime
#  ip              :string(255)
#  map             :string(255)
#  max_players     :integer
#  name            :string(255)
#  official        :boolean
#  password        :string(255)
#  ping            :string(255)
#  players         :integer
#  port            :string(255)
#  recordable_type :string(255)
#  recording       :string(255)
#  reservation     :string(255)
#  status          :string(255)      default("offline"), not null
#  version         :integer
#  created_at      :datetime
#  updated_at      :datetime
#  category_id     :integer
#  default_id      :integer
#  recordable_id   :integer
#  user_id         :integer
#
# Indexes
#
#  index_servers_on_default_id          (default_id)
#  index_servers_on_players_and_domain  (players,domain)
#  index_servers_on_user_id             (user_id)
#

require 'yaml'

class Server < ApplicationRecord
  include Extra

  DOMAIN_HLDS = 0
  DOMAIN_HLTV = 1
  DOMAIN_NS2 = 2

  STATUS_OFFLINE = 'offline'
  STATUS_ONLINE = 'online'

  attr_accessor :pwd

  # attr_protected :id, :user_id, :updated_at, :created_at, :map, :players, :maxplayers, :ping, :version

  validates(*%i[name dns], length: { in: 1..30 })
  validates :password, length: { maximum: 30, allow_blank: true }
  validates :description, length: { maximum: 255, allow_blank: true }
  validates :ip, format: { with: /\A[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\z/ }
  validates :port, format: { with: /\A[0-9]{1,5}\z/ }
  validates :reservation, format: { with: /\A[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}:[0-9]{1,5}\z/,
                                    allow_nil: true }
  validates :pwd, format: { with: /\A[A-Za-z0-9_-]*\z/, allow_nil: true }
  validates :status, inclusion: { in: [STATUS_OFFLINE, STATUS_ONLINE] }

  scope :ordered, -> { order('name') }
  scope :hlds, -> { where('domain = ?', DOMAIN_HLDS) }
  scope :ns2, -> { where('domain = ?', DOMAIN_NS2) }
  scope :hltvs, -> { where('domain = ?', DOMAIN_HLTV) }
  scope :active, -> { where('active = 1') }
  scope :unreserved_hltv_around, lambda { |time|
    start_time = time.ago(Match::MATCH_LENGTH).utc
    end_time = time.ago(-Match::MATCH_LENGTH).utc
    start_q = ActiveRecord::Base.connection.quote(start_time.strftime('%Y-%m-%d %H:%M:%S'))
    end_q = ActiveRecord::Base.connection.quote(end_time.strftime('%Y-%m-%d %H:%M:%S'))
    select('servers.*')
      .joins("LEFT JOIN matches ON servers.id = matches.hltv_id
    AND match_time > #{start_q}
    AND match_time < #{end_q}")
      .where('matches.hltv_id IS NULL')
  }

  has_many :log_lines, dependent: :destroy
  has_many :matches, dependent: :nullify
  has_many :challenges, dependent: :nullify
  belongs_to :user, optional: true
  belongs_to :recordable, polymorphic: true, optional: true

  before_create :set_category

  has_paper_trail on: [:update], only: %i[map max_players status]

  def domains
    { DOMAIN_HLTV => 'HLTV', DOMAIN_HLDS => 'NS Server', DOMAIN_NS2 => 'NS2 Server' }
  end

  def to_s
    name
  end

  def api_v1_payload
    {
      id: id,
      name: name,
      description: description,
      dns: dns,
      ip: ip,
      port: port,
      password: password,
      category_id: category_id
    }
  end

  def self.active_api_v1_payload
    active.map(&:api_v1_payload)
  end

  def online?
    status == STATUS_ONLINE
  end

  def disabled
    !active
  end

  def disabled=(value)
    self.active = !ActiveModel::Type::Boolean.new.cast(value)
  end

  def addr
    "#{ip}:#{port}"
  end

  def set_category
    self.category_id = (domain == DOMAIN_NS2 ? 45 : 44)
  end

  def free?(time)
    challenges.around(time).pending.count.zero? and matches.around(time).count.zero?
  end

  alias is_free free?

  def can_create?(cuser)
    cuser
  end

  def can_update?(cuser)
    cuser&.admin? or user == cuser
  end

  def can_destroy?(cuser)
    cuser&.admin?
  end

  def self.move(addr, newaddr, newpwd)
    hltvs.where(reservation => addr).find_each do |hltv|
      hltv.reservation = newaddr
      hltv.pwd = newpwd
      hltv.save!
    end
  end

  def self.stop(addr)
    hltvs.where(reservation: addr).find_each do |hltv|
      hltv.reservation = nil
      hltv.save!
    end
  end

  def self.params(params, _cuser)
    params.require(:server).permit(:dns, :ip, :port, :password, :name, :description, :domain, :official, :disabled)
  end
end
