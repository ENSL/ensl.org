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
