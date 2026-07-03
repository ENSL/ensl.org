# frozen_string_literal: true

module Passkeys
  class LoginService
    def initialize(session:, request:)
      @session = session
      @request = request
    end

    def challenge(username:)
      user = User.where('BINARY username = ?', username.to_s).first
      raise Error.new(I18n.t(:passkey_unavailable), status: :unprocessable_content) unless user&.passkey_enabled?

      Webauthn.configure!(@request)

      options = WebAuthn::Credential.options_for_get(
        allow: user.passkey_credentials.map(&:external_id),
        user_verification: 'preferred'
      )

      @session[:passkey_login] = {
        challenge: options.challenge,
        user_id: user.id,
        expires_at: 5.minutes.from_now.to_i
      }

      options
    rescue Passkeys::Error
      raise
    rescue StandardError => e
      Rails.logger.warn("Passkey options failed: #{e.class}: #{e.message}")
      raise Error.new(I18n.t(:passkey_unavailable), status: :unprocessable_content)
    end

    def authenticate(credential_params:)
      state = pending_state(@session[:passkey_login], :passkey_expired)
      user = User.find_by(id: state[:user_id])
      raise Error.new(I18n.t(:passkey_unavailable), status: :unprocessable_content) unless user

      Webauthn.configure!(@request)

      credential = WebAuthn::Credential.from_get(credential_params)
      stored = user.passkey_credentials.find_by(external_id: credential.id)
      raise Error.new(I18n.t(:passkey_invalid), status: :unauthorized) unless stored

      credential.verify(
        state[:challenge],
        public_key: stored.public_key,
        sign_count: stored.sign_count
      )

      stored.update!(sign_count: credential.sign_count, last_used_at: Time.current)
      @session.delete(:passkey_login)
      user
    rescue Passkeys::Error
      raise
    rescue WebAuthn::Error => e
      Rails.logger.info("Passkey authentication failed: #{e.class}: #{e.message}")
      raise Error.new(I18n.t(:passkey_invalid), status: :unauthorized)
    rescue StandardError => e
      Rails.logger.warn("Passkey authentication error: #{e.class}: #{e.message}")
      raise Error.new(I18n.t(:passkey_unavailable), status: :unprocessable_content)
    end

    private

    def pending_state(data, error_key)
      raise Error.new(I18n.t(:login_otp_session_missing), status: :unauthorized) unless data.is_a?(Hash)

      state = data.with_indifferent_access
      return state if state[:expires_at].to_i >= Time.current.to_i

      raise Error.new(I18n.t(error_key), status: :unauthorized)
    end
  end
end
