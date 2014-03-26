# == Schema Information
#
# Table name: profiles
#
#  id                  :integer          not null, primary key
#  user_id             :integer
#  msn                 :string(255)
#  icq                 :string(255)
#  irc                 :string(255)
#  web                 :string(255)
#  town                :string(255)
#  singleplayer        :string(255)
#  multiplayer         :string(255)
#  food                :string(255)
#  beverage            :string(255)
#  hobby               :string(255)
#  music               :string(255)
#  book                :string(255)
#  movie               :string(255)
#  tvseries            :string(255)
#  res                 :string(255)
#  sensitivity         :string(255)
#  monitor_hz          :string(255)
#  scripts             :string(255)
#  cpu                 :string(255)
#  gpu                 :string(255)
#  ram                 :string(255)
#  psu                 :string(255)
#  motherboard         :string(255)
#  soundcard           :string(255)
#  hdd                 :string(255)
#  case                :string(255)
#  monitor             :string(255)
#  mouse               :string(255)
#  mouse_pad           :string(255)
#  keyboard            :string(255)
#  head_phones         :string(255)
#  speakers            :string(255)
#  achievements        :text
#  updated_at          :datetime
#  signature           :string(255)
#  avatar              :string(255)
#  clan_search         :string(255)
#  notify_news         :boolean
#  notify_articles     :boolean
#  notify_movies       :boolean
#  notify_gather       :boolean
#  notify_own_match    :boolean
#  notify_any_match    :boolean
#  notify_pms          :boolean          default(TRUE), not null
#  notify_challenge    :boolean          default(TRUE), not null
#  steam_profile       :string(255)
#  achievements_parsed :string(255)
#  signature_parsed    :string(255)
#

require 'rbbcode'

class Profile < ActiveRecord::Base
  include Extra

  attr_protected :user_id, :id, :updated_at, :created_at

  belongs_to :user

  validates_length_of :msn, :maximum => 50
  validates_format_of :msn, :with => /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i, :allow_blank => true
  validates_format_of :icq, :with => /\A[0-9\-]{1,9}\z/, :allow_blank => true
  validates_length_of :irc, :maximum => 20
  validates_length_of :web, :maximum => 100
  validates_length_of :town, :maximum => 20
  validates_length_of [:singleplayer, :multiplayer, :food, :beverage, :hobby, :music, :book, :movie, :tvseries], :maximum => 120
  validates_length_of [:res, :sensitivity, :monitor_hz], :maximum => 30
  validates_length_of [:scripts, :cpu, :gpu, :ram, :psu, :motherboard, :soundcard, :hdd, :case, :monitor, :mouse, :mouse_pad, :keyboard, :head_phones, :speakers], :maximum => 100
  validates_length_of :signature, :maximum => 255
  validates_length_of :achievements, :maximum => 65000
  validates_format_of :steam_profile, :with => /\A[A-Za-z0-9_\-\+]{1,40}\z/, :allow_blank => true

  before_validation :init_steam_profile
  before_save :parse_text

  mount_uploader :avatar, AvatarUploader

  def init_steam_profile
    if steam_profile
      if (m = steam_profile.to_s.match(/http:\/\/steamcommunity\.com\/profiles\/([0-9]*)/))
        self.steam_profile = m[1]
      elsif (m = steam_profile.to_s.match(/http:\/\/steamcommunity\.com\/id\/([A-Za-z0-9_\-\+]*)/))
        self.steam_profile = m[1]
      end
    end
  end

  def parse_text
    self.achievements_parsed = RbbCode::Parser.new.parse(achievements) if self.achievements
    self.signature_parsed = RbbCode::Parser.new.parse(signature) if self.signature
  end
end
