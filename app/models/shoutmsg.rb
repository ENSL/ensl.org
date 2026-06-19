# frozen_string_literal: true

# == Schema Information
#
# Table name: shoutmsgs
#
#  id             :integer          not null, primary key
#  shoutable_type :string(255)
#  text           :string(255)
#  created_at     :datetime
#  updated_at     :datetime
#  shoutable_id   :integer
#  user_id        :integer
#
# Indexes
#
#  index_shoutmsgs_on_shoutable_type_and_shoutable_id  (shoutable_type,shoutable_id)
#  index_shoutmsgs_on_user_id                          (user_id)
#

class Shoutmsg < ActiveRecord::Base
  include Extra

  # attr_protected :id, :created_at, :updated_at, :user_id

  validates_length_of :text, in: 1..100
  validates_presence_of :user

  belongs_to :user, optional: true
  belongs_to :shoutable, polymorphic: true, optional: true

  scope :recent, -> { includes(:user).order('id DESC').limit(8) }
  scope :box, -> { where(shoutable_type: nil, shoutable_id: nil).limit(8) }
  scope :typebox, -> { where(shoutable_type: nil, shoutable_id: nil) }
  scope :last500, -> { includes(:user).order('id DESC').limit(500) }
  scope :of_object, ->(object, id) { where(shoutable_type: object, shoutable_id: id) }
  scope :ordered, -> { order('id') }

  after_create_commit :broadcast_shoutmsg
  before_validation :normalize_emoji_aliases

  def domain
    self[:shoutable_type] ? "shout_#{shoutable_type}_#{shoutable_id}" : 'shoutbox'
  end

  def can_create?(cuser)
    cuser && !cuser.banned?(Ban::TYPE_MUTE) && cuser.verified?
  end

  def can_destroy?(cuser)
    cuser&.admin?
  end

  private

  def normalize_emoji_aliases
    self.text = EmojiParser.parse(text.to_s, &:raw)
  end

  def broadcast_shoutmsg
    # Reload from DB to ensure associations (user) are present when rendering in the job
    shout = Shoutmsg.find_by(id: id)
    return unless shout

    # Ensure the associated user object is loaded (avoid helpers trying to lookup a nil id)
    shout.user = User.find_by(id: shout.user_id) if shout.user_id.present?

    begin
      # Render the partial to capture the exact turbo-stream/html payload for debugging
      html = ApplicationController.render(partial: 'shoutmsgs/shoutmsg', locals: { shoutmsg: shout, user: shout.user })
      Rails.logger.info "Shoutmsg broadcast: stream_name=#{shout.domain.inspect} target=#{shout.domain.inspect} payload_size=#{html.bytesize}"
      if shout.shoutable_type.present?
        broadcast_append_to shout.domain, target: shout.domain, html: html
      else
        broadcast_prepend_to 'shoutbox', target: 'shoutbox', html: html
      end
    rescue StandardError => e
      Rails.logger.error "Shoutmsg broadcast failed: #{e.class}: #{e.message} -- shout_id=#{shout.id.inspect}, user_id=#{shout.user_id.inspect}, user=#{shout.user.inspect}"
    end
  end

  def self.flood?(cuser, type = nil, id = nil)
    return false if of_object(type, id).count < 3

    of_object(type, id).all(order: 'created_at DESC', limit: 10).each do |msg|
      return false if cuser != msg.user
    end
    true
  end

  def self.params(params, _cuser)
    params.require(:shoutmsg).permit(:shoutable_id, :shoutable_type, :text)
  end
end
