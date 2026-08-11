# frozen_string_literal: true

# Shared session/authentication helpers used by controllers that need to
# establish or guard a logged-in session (e.g. SessionsController for login
# and UsersController for self-registration auto-login).
module Authentication
  extend ActiveSupport::Concern

  included do
    helper_method :cuser
    before_action :update_user
  end

  def cuser
    return @cuser if defined?(@cuser) && @cuser

    user_id = nil
    begin
      user_id = session[:user]
    rescue StandardError
      user_id = nil
    end

    @cuser = User.find(user_id) if user_id
    @cuser
  rescue StandardError
    @cuser = nil
  end

  def permitted_webauthn_credential_params
    params.require(:credential).permit(
      :id,
      :rawId,
      :type,
      :authenticatorAttachment,
      clientExtensionResults: {},
      response: [
        :attestationObject,
        :authenticatorData,
        :clientDataJSON,
        :publicKey,
        :publicKeyAlgorithm,
        :signature,
        :userHandle,
        { transports: [] }
      ]
    ).to_h
  end

  private

  def save_session(user)
    return_to = session[:return_to]
    # Drop any leftover auth-handshake data (OpenID discovery, passkey/OTP challenges,
    # cached_user, etc.) that accumulated in the session before login, and rotate the
    # session id to guard against session fixation.
    reset_session
    session[:return_to] = return_to
    session[:user] = user.id
    user.record_login!(request.ip)
  end

  def already_logged_in?
    return false unless cuser && !cuser.admin?

    flash[:notice] = 'You are already logged in.'
    redirect_to edit_user_path(cuser)
    true
  end

  # Refresh the logged-in user's timezone/last-visit, self-heal a missing profile, and log
  # out anyone who has since been banned.
  def update_user
    user = cuser
    return unless user

    Time.zone = user.time_zone
    user.touch_last_visit_if_stale!

    flash[:notice] = 'Your profile has been removed and recreated.' if user.ensure_profile!

    return unless user.banned? Ban::TYPE_SITE

    session[:user] = nil
    @cuser = nil
  end
end
