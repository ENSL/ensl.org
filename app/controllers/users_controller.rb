# frozen_string_literal: true

class UsersController < ApplicationController
  before_action :load_user, only: %i[show history popup agenda edit update destroy]
  respond_to :html, :js

  # OmniAuth callback is a cross-origin GET from the provider; skip CSRF checks here.
  skip_forgery_protection only: :callback
  prepend_before_action :reject_js_callback, only: :callback

  PAGES = %w[general favorites computer articles movies teams matches predictions comments].freeze

  def index
    search = params[:search]
    @users = if search&.match(/^ip:(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})$/) && cuser&.admin?
               User.where(lastip: ::Regexp.last_match(1)).paginate(per_page: 40, page: params[:page])
             elsif params[:filter] == 'lately'
               User.search(params[:search]).lately.paginate(per_page: 40, page: params[:page])
             else
               User.search(params[:search]).paginate(per_page: 40, page: params[:page])
             end
  end

  def show
    @page = 'general'
    respond_to do |format|
      format.js do
        @page = params[:page] if PAGES.include?(params[:page])
      end
      format.html {}
    end
  end

  # FIXME: consider merging
  def popup
    render layout: false
  end

  def agenda
    raise AccessError unless (@user == cuser) || cuser&.admin?

    @teamer = Teamer.new
    @teamer.user = @user
  end

  def history
    raise AccessError unless cuser&.admin?
  end

  def new
    return if already_logged_in?

    # Use cached OAuth-created user only for anonymous visitors.
    if session[:cached_user]&.present? && cuser.nil?
      @user = begin
        User.new(JSON.parse(session[:cached_user]))
      rescue StandardError
        nil
      end
      session.delete :cached_user
    end
    @user ||= User.new
    @user.profile = Profile.new
    @user.lastip = request.env['REMOTE_ADDR']
    @user.can_create? cuser
    @user.preformat
  end

  def edit
    raise AccessError unless @user.can_update? cuser
  end

  def create
    return if already_logged_in?

    user = User.build_for_registration(raw_params: params, actor: cuser, remote_ip: request.env['REMOTE_ADDR'])

    raise AccessError unless user.can_create? cuser

    if user.register_with_preformat
      redirect_to action: :show, id: user.id
      save_session user
    else
      @user = user
      render :new
    end
  end

  def update
    raise AccessError unless @user.can_update? cuser

    if defined?(Rails) && Rails.configuration.x.respond_to?(:debug_prints) && Rails.configuration.x.debug_prints
      Rails.logger.debug(params.inspect)
    end

    if @user.update(@user.filtered_update_attributes(params, cuser))
      flash[:notice] = t(:user_updated)
      redirect_back(fallback_location: user_path(@user))
    else
      flash[:error] = t(:user_update_failed)
      render :edit
    end
  end

  def destroy
    raise AccessError unless @user.can_destroy? cuser

    @user.destroy
    redirect_to users_url
  end

  def callback
    unless request.env['omniauth.auth']
      callback_failed('Steam callback: auth_hash is missing')
      return
    end

    user = User.find_or_build(auth_hash, request.ip)
    unless user.is_a?(ActiveRecord::Base)
      callback_failed
      return
    end

    cache_callback_user(user)

    if user.new_record?
      render_new_user_from_callback(user)
    else
      login_user(user)
      return_back
    end
  end

  # FIXME: maybe move to session controller
  def login
    if params[:login]
      Rails.logger.info(
        "Login attempt username=#{params[:login][:username].to_s.inspect} " \
        "ip=#{request.ip} ua=#{request.user_agent.to_s.inspect}"
      )
      if (u = User.authenticate(params[:login]))
        Rails.logger.info("Login success user_id=#{u.id} username=#{u.username}")
        login_user(u)
      else
        Rails.logger.warn(
          "Login failed username=#{params[:login][:username].to_s.inspect} " \
          "ip=#{request.ip}"
        )
        flash[:error] = t(:login_unsuccessful)
      end
    end
    return_back
  end

  def logout
    session[:user] = nil
    flash[:notice] = t(:login_out)
    redirect_to :root
  end

  def forgot
    return unless request.post?

    if (user1 = User.where(username: params[:username], email: params[:email]).first) && user1.send_new_password
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

  def load_user
    @user = User.find(params[:id])
  end

  def already_logged_in?
    return false unless cuser && !cuser.admin?

    flash[:notice] = 'You are already logged in.'
    redirect_to edit_user_path(cuser)
    true
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

  def render_new_user_from_callback(user)
    @user = user
    # If user mistypes username and password, return to user creation page.
    session[:return_to] = new_user_url(@user)

    # if @user.created_at > (Time.zone.now - 1.week)
    # flash[:notice] = t(:users_signup_steam)
    render :new, formats: :html
  end

  def login_user(user)
    if user.banned? Ban::TYPE_SITE
      flash[:error] = t(:accounts_locked)
    else
      flash[:notice] = t(:login_successful)
      # FIXME: this doesn't work because model is saved before
      flash[:notice] << " \n#{I18n.t(:password_md5_scrypt)}" if user.password_hash_changed?
      if !session[:verified_steamid].blank? && \
         (user.steamid != session[:verified_steamid]) && \
         user.update_attribute(:steamid, session[:verified_steamid])
        session[:return_to] = edit_user_path(user)
        flash[:notice] << format(t(:users_steamid_update), user.steamid)
        session.delete :verified_steamid
      end
      save_session user
    end
  end

  def save_session(user)
    session[:user] = user.id
    user.update_columns(lastip: request.ip, lastvisit: Time.now.utc)
  end

  def auth_hash
    request.env['omniauth.auth']
  end
end
