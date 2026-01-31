class UsersController < ApplicationController
  before_action :get_user, only: %i[show history popup agenda edit update destroy]
  respond_to :html, :js

  # OmniAuth callback is a cross-origin GET from the provider; skip CSRF checks here.
  skip_forgery_protection only: :callback
  prepend_before_action :reject_js_callback, only: :callback

  PAGES = %w[general favorites computer articles movies teams matches predictions comments]

  def index
    search = params[:search]
    @users = if search && search.match(/^ip:(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})$/) && cuser&.admin?
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
    raise AccessError unless @user == cuser or cuser&.admin?

    @teamer = Teamer.new
    @teamer.user = @user
  end

  def history
    raise AccessError unless cuser&.admin?
  end

  def new
    unless session[:cached_user]&.blank?
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
    @user = User.new(User.params(params, cuser, 'create'))
    @user.lastip = request.env['REMOTE_ADDR']

    raise AccessError unless @user.can_create? cuser

    if @user.valid? and @user.save
      redirect_to action: :show, id: @user.id
      save_session @user
    else
      @user.preformat
      render :new
    end
  end

  def update
    raise AccessError unless @user.can_update? cuser

    if defined?(Rails) && Rails.configuration.x.respond_to?(:debug_prints) && Rails.configuration.x.debug_prints
      Rails.logger.debug(params.inspect)
    end

    # FIXME: use permit
    params[:user].delete(:username) unless @user.can_change_name? cuser
    if @user.update(User.params(params, cuser, 'update'))
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
    @user = User.find_or_build(auth_hash, request.ip)
    unless @user and @user.is_a?(ActiveRecord::Base)
      flash[:error] = t(:users_callback_fail)
      redirect_to_home
      return
    end

    # After steam validates SteamID, we know its right.
    session[:verified_steamid] = @user.steamid

    # Store user in session store
    session[:cached_user] = @user.to_json

    if @user.new_record?
      # If user mistypes username and password, return to user creation page.
      session[:return_to] = new_user_url(@user)

      # if @user.created_at > (Time.zone.now - 1.week)
      # flash[:notice] = t(:users_signup_steam)
      render :new
    else
      login_user(@user)
      return_back
    end
  end

  # FIXME: maybe move to session controller
  def login
    if params[:login]
      if (u = User.authenticate(params[:login]))
        login_user(u)
      else
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
    return unless request.format.js?

    head :not_acceptable
  end

  def get_user
    @user = User.find(params[:id])
  end

  def login_user(user)
    if user.banned? Ban::TYPE_SITE
      flash[:error] = t(:accounts_locked)
    else
      flash[:notice] = format('%s', t(:login_successful))
      # FIXME: this doesn't work because model is saved before
      flash[:notice] << " \n%s" % I18n.t(:password_md5_scrypt) if user.password_hash_changed?
      if !session[:verified_steamid].blank? and \
         user.steamid != session[:verified_steamid] and \
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
    user.lastip = request.ip
    user.lastvisit = Time.now.utc
    user.save!
  end

  def auth_hash
    request.env['omniauth.auth']
  end
end
