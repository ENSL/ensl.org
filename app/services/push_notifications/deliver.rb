# frozen_string_literal: true

module PushNotifications
  # Delivers a payload to every subscription belonging to the given users, dropping
  # subscriptions the push service reports as gone (browser data cleared, permission revoked).
  class Deliver
    def self.call(...)
      new(...).call
    end

    def initialize(user_ids:, payload:, ttl: 600)
      @user_ids = Array(user_ids).uniq
      @payload = payload
      @ttl = ttl
    end

    def call
      return 0 unless WebPushCredentials.configured?
      return 0 if @user_ids.empty?

      PushSubscription.for_users(@user_ids).find_each.count { |subscription| deliver(subscription) }
    end

    private

    def deliver(subscription)
      WebPush.payload_send(
        message: @payload.to_json,
        endpoint: subscription.endpoint,
        p256dh: subscription.p256dh_key,
        auth: subscription.auth_key,
        vapid: vapid_options,
        ttl: @ttl
      )
      true
    rescue WebPush::ExpiredSubscription, WebPush::InvalidSubscription, WebPush::Unauthorized
      subscription.destroy
      false
    rescue StandardError => e
      Rails.logger.warn("[PushNotifications] delivery failed subscription=#{subscription.id}: #{e.message}")
      false
    end

    def vapid_options
      {
        subject: WebPushCredentials.subject,
        public_key: WebPushCredentials.public_key,
        private_key: WebPushCredentials.private_key
      }
    end
  end
end
