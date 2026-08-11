# frozen_string_literal: true

# Shared session/authentication helpers used by controllers that need to
# establish or guard a logged-in session (e.g. SessionsController for login
# and UsersController for self-registration auto-login).
module Authentication
  extend ActiveSupport::Concern

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
end
