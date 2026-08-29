# frozen_string_literal: true

# == Schema Information
#
# Table name: push_subscriptions
#
#  id         :integer          not null, primary key
#  auth_key   :string(255)      not null
#  endpoint   :string(500)      not null
#  p256dh_key :string(255)      not null
#  user_agent :string(255)
#  created_at :datetime
#  updated_at :datetime
#  user_id    :integer          not null
#
# Indexes
#
#  index_push_subscriptions_on_endpoint  (endpoint) UNIQUE
#  index_push_subscriptions_on_user_id   (user_id)
#

# A browser Web Push (VAPID) endpoint registered by a user. Users can have several,
# one per browser/device they opted in from.
class PushSubscription < ApplicationRecord
  belongs_to :user

  validates :endpoint, presence: true, length: { maximum: 500 }, uniqueness: true
  validates :p256dh_key, :auth_key, presence: true, length: { maximum: 255 }

  scope :for_users, ->(user_ids) { where(user_id: user_ids) }

  def self.register!(user:, endpoint:, p256dh_key:, auth_key:, user_agent: nil)
    subscription = find_or_initialize_by(endpoint: endpoint)
    subscription.update!(
      user: user,
      p256dh_key: p256dh_key,
      auth_key: auth_key,
      user_agent: user_agent.to_s.first(255).presence
    )
    subscription
  end
end
