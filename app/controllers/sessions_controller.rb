# frozen_string_literal: true

# Handles user session lifecycle: username/password login, logout, OmniAuth
# (Steam) callback sign-in/registration hand-off, and password recovery.
class SessionsController < ApplicationController
  include Authentication

  respond_to :html, :js

  # OmniAuth callback is a cross-origin GET from the provider; skip CSRF checks here.
  skip_forgery_protection only: :callback
  prepend_before_action :reject_js_callback, only: :callback

  def callback
    return callback_failed('Steam callback: auth_hash is missing') unless auth_hash

    user = User.find_or_build(auth_hash, request.ip)
    return callback_failed unless callback_user?(user)

    cache_callback_user(user)
    return render_new_user_from_callback(user) if user.new_record?

    login_user(user)
    return_back
  end

  def login
    process_login_attempt if params[:login]
    return_back
  end

  def logout
    session[:user] = nil
    flash[:notice] = t(:login_out)
    redirect_to :root
  end

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
      login_user(user)
    else
      log_failed_login
      flash[:error] = t(:login_unsuccessful)
    end
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
    save_session user
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
