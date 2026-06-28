# frozen_string_literal: true

# == Schema Information
#
# Table name: profiles
#
#  id                  :integer          not null, primary key
#  achievements        :text(65535)
#  achievements_parsed :string(400)
#  avatar              :string(255)
#  beverage            :string(255)
#  book                :string(255)
#  case                :string(255)
#  clan_search         :string(255)
#  cpu                 :string(255)
#  food                :string(255)
#  gpu                 :string(255)
#  hdd                 :string(255)
#  head_phones         :string(255)
#  hobby               :string(255)
#  icq                 :string(255)
#  irc                 :string(255)
#  keyboard            :string(255)
#  layout              :string(255)
#  monitor             :string(255)
#  monitor_hz          :string(255)
#  motherboard         :string(255)
#  mouse               :string(255)
#  mouse_pad           :string(255)
#  movie               :string(255)
#  msn                 :string(255)
#  multiplayer         :string(255)
#  music               :string(255)
#  notify_any_match    :boolean
#  notify_articles     :boolean
#  notify_challenge    :boolean          default(TRUE), not null
#  notify_gather       :boolean
#  notify_movies       :boolean
#  notify_news         :boolean
#  notify_own_match    :boolean
#  notify_pms          :boolean          default(TRUE), not null
#  psu                 :string(255)
#  ram                 :string(255)
#  res                 :string(255)
#  scripts             :string(255)
#  sensitivity         :string(255)
#  signature           :string(255)
#  signature_parsed    :text(65535)
#  singleplayer        :string(255)
#  soundcard           :string(255)
#  speakers            :string(255)
#  steam_profile       :string(255)
#  stream              :string(255)
#  town                :string(255)
#  tvseries            :string(255)
#  web                 :string(255)
#  updated_at          :datetime
#  user_id             :integer
#
# Indexes
#
#  index_profiles_on_user_id  (user_id)
#

class Profile < ApplicationRecord
  include Extra

  # attr_protected :user_id, :id, :updated_at, :created_at

  belongs_to :user, optional: true

  validates :msn, length: { maximum: 50 }
  validates :msn, format: { with: /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i, allow_blank: true }
  validates :icq, format: { with: /\A[0-9-]{1,9}\z/, allow_blank: true }
  validates :irc, length: { maximum: 20 }
  validates :web, length: { maximum: 100 }
  validates :town, length: { maximum: 20 }
  validates(*%i[singleplayer multiplayer food beverage hobby music book movie tvseries],
            length: { maximum: 120 })
  validates(*%i[res sensitivity monitor_hz], length: { maximum: 30 })
  validates(*%i[scripts cpu gpu ram psu motherboard soundcard hdd case monitor mouse mouse_pad keyboard head_phones speakers],
            length: { maximum: 100 })
  validates :signature, length: { maximum: 255 }
  validates :achievements, length: { maximum: 65_000 }
  validates :steam_profile, format: { with: /\A[A-Za-z0-9_\-+]{1,40}\z/, allow_blank: true }

  validates :stream, length: { maximum: 255 }

  before_validation :init_steam_profile
  before_save :parse_text

  mount_uploader :avatar, AvatarUploader

  def init_steam_profile
    return unless steam_profile

    if (m = steam_profile.to_s.match(%r{http://steamcommunity\.com/profiles/([0-9]*)}))
      self.steam_profile = m[1]
    elsif (m = steam_profile.to_s.match(%r{http://steamcommunity\.com/id/([A-Za-z0-9_\-+]*)}))
      self.steam_profile = m[1]
    end
  end

  def parse_text
    self.achievements_parsed = bbcode_to_html(achievements) if achievements
    self.signature_parsed = bbcode_to_html(signature) if signature
  end

  def self.params(params, _cuser)
    # FIXME: check this, add user_id
    # TEST
    params.require(:profile).except!(:id, :updated_at).permit!
  end
end
