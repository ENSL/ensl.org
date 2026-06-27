# frozen_string_literal: true

# Shared session/authentication helpers used by controllers that need to
# establish or guard a logged-in session (e.g. SessionsController for login
# and UsersController for self-registration auto-login).
module Authentication
  extend ActiveSupport::Concern

  private

  def save_session(user)
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
