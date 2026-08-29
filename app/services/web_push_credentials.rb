# frozen_string_literal: true

# VAPID keypair used to sign Web Push requests. Generate one with `rake web_push:generate_keys`
# and expose it through the environment; without it push notifications stay switched off.
module WebPushCredentials
  module_function

  def public_key
    ENV['VAPID_PUBLIC_KEY'].presence
  end

  def private_key
    ENV['VAPID_PRIVATE_KEY'].presence
  end

  def subject
    ENV['VAPID_SUBJECT'].presence || 'mailto:staff@ensl.org'
  end

  def configured?
    public_key.present? && private_key.present?
  end
end
