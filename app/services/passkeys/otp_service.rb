# frozen_string_literal: true

module Passkeys
  class OtpService
    def initialize(session:, request:)
      @session = session
      @request = request
    end

    def challenge(user)
      code = format('%06d', SecureRandom.random_number(1_000_000))

      @session[:pending_login_otp] = {
        user_id: user.id,
        code_digest: Digest::SHA256.hexdigest(code),
        expires_at: 10.minutes.from_now.to_i
      }

      Notifications.login_otp(user, code).deliver
    rescue StandardError => e
      Rails.logger.warn("OTP delivery failed for user_id=#{user.id}: #{e.class}: #{e.message}")
      raise Error.new(I18n.t('sessions.otp.send_failed'), status: :unprocessable_content)
    end

    def verify(code:)
      state = pending_state
      raise Error.new(I18n.t('sessions.otp.invalid'), status: :unauthorized) if code.to_s.strip.blank?

      submitted_digest = Digest::SHA256.hexdigest(code.to_s.strip)
      expected_digest = state[:code_digest].to_s

      unless expected_digest.length == submitted_digest.length && ActiveSupport::SecurityUtils.secure_compare(
        submitted_digest, expected_digest
      )
        raise Error.new(I18n.t('sessions.otp.invalid'), status: :unauthorized)
      end

      user = User.find_by(id: state[:user_id])
      raise Error.new(I18n.t('sessions.create.failure'), status: :unauthorized) unless user

      @session.delete(:pending_login_otp)
      user
    end

    def clear!
      @session.delete(:pending_login_otp)
    end

    private

    def pending_state
      data = @session[:pending_login_otp]
      raise Error.new(I18n.t('sessions.otp.session_missing'), status: :unauthorized) unless data.is_a?(Hash)

      state = data.with_indifferent_access
      if state[:expires_at].to_i < Time.current.to_i
        raise Error.new(I18n.t('sessions.otp.expired'),
                        status: :unauthorized)
      end

      state
    end
  end
end
