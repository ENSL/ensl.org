# frozen_string_literal: true

module Passkeys
  class Webauthn
    def self.configure!(request)
      ::WebAuthn.configure do |config|
        config.rp_name = ENV.fetch('WEBAUTHN_RP_NAME', 'ENSL')
        config.rp_id = ENV['WEBAUTHN_RP_ID'].presence || request.host
        config.allowed_origins = Array(ENV['WEBAUTHN_ORIGIN'].presence || request.base_url)
      end
    end
  end
end
