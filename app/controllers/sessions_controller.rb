# frozen_string_literal: true

# Handles user session lifecycle: username/password login, logout, OmniAuth
# (Steam) callback sign-in/registration hand-off, and password recovery.
class SessionsController < ApplicationController
  include Authentication

  respond_to :html, :js

  # OmniAuth callback is a cross-origin GET from the provider; skip CSRF checks here.
  skip_forgery_protection only: %i[callback passkey_options]
  prepend_before_action :reject_js_callback, only: :callback

  # GET /auth/steam/callback
  #
  # callback is the endpoint that OmniAuth redirects to after a user has
  # authenticated with Steam. It handles both new user registration and existing
  # user login. If the user is new, it will render the new user registration form
  # with the Steam-provided information pre-filled. If the user is existing, it will
  # log them in and redirect them to the appropriate page.
  def callback
    return callback_failed('Steam callback: auth_hash is missing') unless auth_hash

    user = User.find_or_build(auth_hash, request.ip)
    return callback_failed unless callback_user?(user)

    cache_callback_user(user)
    return render_new_user_from_callback(user) if user.new_record?

    login_user(user)
    return_back
  end

  # GET /login
  # POST /login
  # This action handles both displaying the login form and processing login attempts.
  # If the request is a POST, it will attempt to authenticate the user with the provided
  # credentials. If the request is a GET, it will simply render the login form.
  def login
    if params[:login_otp]
      verify_pending_otp
    elsif params[:login]
      process_login_attempt
    end
    return_back
  end

  # GET /passkey_options
  #
  # This action is used to initiate a passkey login process. It generates a challenge for
  # the user based on their username and returns it as a JSON response. If there is an error
  # during this process, it will return an error message and status code.
  def passkey_options
    options = passkey_login_service.challenge(username: params[:username])
    render json: options
  rescue Passkeys::Error => e
    render json: { error: e.message }, status: e.status
  end

  # POST /passkey_authenticate
  #
  # This action is used to authenticate a user using a passkey. It takes the credential parameters
  # from the request, attempts to authenticate the user, and logs them in if successful.
  # If the authentication fails, it returns an error message and status code.
  def passkey_authenticate
    user = passkey_login_service.authenticate(credential_params: passkey_credential_params)
    login_user(user)

    redirect_to = session.delete(:return_to).presence || root_path
    render json: { redirect_to: redirect_to }
  rescue Passkeys::Error => e
    render json: { error: e.message }, status: e.status
  end

  # GET /logout
  #
  # This action logs the user out by clearing their session and redirecting them to the home page.
  def logout
    session[:user] = nil
    flash[:notice] = t(:login_out)
    redirect_to :root
  end

  # GET /forgot
  # POST /forgot
  #
  # This action handles password recovery. If the request is a POST, it will attempt to send a
  # password reset email to the user based on the provided username and email. If successful,
  # it will display a success message; otherwise, it will display an error message.
  def forgot
    return unless request.post?

    if User.reset_password_for_identity(username: params[:username], email: params[:email])
      flash[:notice] = t(:passwords_sent)
    else
      flash[:error] = t(:incorrect_information)
    end
  end

  private

  def reject_js_callback
    # Reject AJAX/XHR requests to prevent cross-origin AJAX from stealing auth
    # but allow regular form submissions (even if Turbo/JS-enabled)
    return unless request.format.js? && request.xhr?

    head :not_acceptable
  end

  def callback_failed(warning = nil)
    flash[:error] = t(:users_callback_fail)
    Rails.logger.warn(warning) if warning
    redirect_to_home
  end

  # Cache the verified SteamID and user data in the session for later use. This is used to
  # persist the verified SteamID across requests, and to store the user data for the duration of the session.
  # The verified SteamID is used to ensure that the user is who they claim to be, and the cached user data is used to avoid repeated database lookups for the same user.
  def cache_callback_user(user)
    payload = user.callback_session_payload
    session[:verified_steamid] = payload[:verified_steamid]
    session[:cached_user] = payload[:cached_user]
  end

  def callback_user?(user)
    user.is_a?(ActiveRecord::Base)
  end

  def process_login_attempt
    log_login_attempt

    if (user = User.authenticate(params[:login]))
      Rails.logger.info("Login success user_id=#{user.id} username=#{user.username}")
      if user.passkey_enabled?
        begin_password_login_otp(user)
      else
        login_user(user)
      end
    else
      log_failed_login
      flash[:error] = t(:login_unsuccessful)
    end
  end

  def verify_pending_otp
    user = otp_service.verify(code: params.dig(:login_otp, :code))
    login_user(user)
  rescue Passkeys::Error => e
    flash[:error] = e.message
  end

  def begin_password_login_otp(user)
    otp_service.challenge(user)
    flash[:notice] = t(:login_otp_sent)
  rescue Passkeys::Error => e
    flash[:error] = e.message
  end

  def log_login_attempt
    Rails.logger.info(
      "Login attempt username=#{params[:login][:username].to_s.inspect} " \
      "ip=#{request.ip} ua=#{request.user_agent.to_s.inspect}"
    )
  end

  def log_failed_login
    Rails.logger.warn(
      "Login failed username=#{params[:login][:username].to_s.inspect} " \
      "ip=#{request.ip}"
    )
  end

  def render_new_user_from_callback(user)
    @user = user
    # If user mistypes username and password, return to user creation page.
    session[:return_to] = new_user_url(@user)

    # if @user.created_at > (Time.zone.now - 1.week)
    # flash[:notice] = t(:users_signup_steam)
    render template: 'users/new', formats: :html
  end

  def login_user(user)
    result = user.apply_login_state!(verified_steamid: session[:verified_steamid])

    return handle_banned_login if result[:banned]

    apply_login_notice(result, user)
    otp_service.clear!
    save_session user
  end

  def passkey_credential_params
    params.require(:credential).permit!.to_h
  end

  def passkey_login_service
    @passkey_login_service ||= Passkeys::LoginService.new(session: session, request: request)
  end

  def otp_service
    @otp_service ||= Passkeys::OtpService.new(session: session, request: request)
  end

  def handle_banned_login
    flash[:error] = t(:accounts_locked)
  end

  def apply_login_notice(result, user)
    flash[:notice] = t(:login_successful)
    append_password_upgrade_notice if result[:password_upgraded]
    apply_steamid_update_notice(user) if result[:steamid_updated]
  end

  def append_password_upgrade_notice
    flash[:notice] << " \n#{I18n.t(:password_md5_scrypt)}"
  end

  def apply_steamid_update_notice(user)
    session[:return_to] = edit_user_path(user)
    flash[:notice] << format(t(:users_steamid_update), user.steamid)
    session.delete :verified_steamid
  end

  def auth_hash
    request.env['omniauth.auth']
  end
end
