# frozen_string_literal: true

module Passkeys
  class RegistrationService
    def initialize(session:, request:)
      @session = session
      @request = request
    end

    def options(user:)
      Webauthn.configure!(@request)

      options = WebAuthn::Credential.options_for_create(
        user: {
          id: user.webauthn_user_handle,
          name: user.username,
          display_name: user.username
        },
        exclude: user.passkey_credentials.map(&:external_id),
        authenticator_selection: {
          user_verification: 'preferred'
        }
      )

      @session[:passkey_registration] = {
        challenge: options.challenge,
        user_id: user.id,
        expires_at: 5.minutes.from_now.to_i
      }

      options
    rescue StandardError => e
      Rails.logger.warn("Passkey registration options failed for user_id=#{user.id}: #{e.class}: #{e.message}")
      raise Error.new(I18n.t(:passkey_unavailable), status: :unprocessable_content)
    end

    def create(user:, credential_params:)
      state = pending_state(user)

      Webauthn.configure!(@request)

      credential = WebAuthn::Credential.from_create(credential_params)
      credential.verify(state[:challenge])

      user.passkey_credentials.create!(
        external_id: credential.id,
        public_key: credential.public_key,
        sign_count: credential.sign_count || 0,
        last_used_at: Time.current
      )

      @session.delete(:passkey_registration)
    rescue ActiveRecord::RecordNotUnique
      raise Error.new(I18n.t(:passkey_unavailable), status: :unprocessable_content)
    rescue WebAuthn::Error => e
      Rails.logger.info("Passkey registration verify failed for user_id=#{user.id}: #{e.class}: #{e.message}")
      raise Error.new(I18n.t(:passkey_invalid), status: :unauthorized)
    rescue StandardError => e
      Rails.logger.warn("Passkey registration failed for user_id=#{user.id}: #{e.class}: #{e.message}")
      raise Error.new(I18n.t(:passkey_unavailable), status: :unprocessable_content)
    end

    private

    def pending_state(user)
      data = @session[:passkey_registration]
      raise Error.new(I18n.t(:passkey_expired), status: :unauthorized) unless data.is_a?(Hash)

      state = data.with_indifferent_access
      raise Error.new(I18n.t(:passkey_expired), status: :unauthorized) if state[:user_id].to_i != user.id
      raise Error.new(I18n.t(:passkey_expired), status: :unauthorized) if state[:expires_at].to_i < Time.current.to_i

      state
    end
  end
end
