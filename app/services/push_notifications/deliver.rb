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
      unless WebPushCredentials.configured?
        Rails.logger.warn('[PushNotifications] skipped: VAPID_PUBLIC_KEY/VAPID_PRIVATE_KEY are not set')
        return 0
      end

      subscriptions = PushSubscription.for_users(@user_ids).to_a
      delivered = subscriptions.count { |subscription| deliver(subscription) }
      Rails.logger.info(
        "[PushNotifications] users=#{@user_ids.size} subscriptions=#{subscriptions.size} delivered=#{delivered}"
      )
      delivered
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
    rescue WebPush::ExpiredSubscription, WebPush::InvalidSubscription, WebPush::Unauthorized => e
      Rails.logger.warn("[PushNotifications] dropping stale subscription=#{subscription.id}: #{e.message}")
      subscription.destroy
      false
    rescue StandardError => e
      Rails.logger.warn("[PushNotifications] delivery failed subscription=#{subscription.id}: #{e.class}: #{e.message}")
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
