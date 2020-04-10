class UsersController < ApplicationController
  before_action :get_user, only: [:show, :history, :popup, :agenda, :edit, :update, :destroy]
  respond_to :html, :js

  PAGES = ["general", "favorites", "computer", "articles", "movies", "teams", "matches", "predictions", "comments"]

  def index
    search = params[:search]
    if search && search.match(/^ip:(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})$/) && cuser&.admin?
      @users = User.where(lastip: $1).paginate(per_page: 40, page: params[:page])
    else
      if params[:filter] == 'lately'
        @users = User.search(params[:search]).lately.paginate(per_page: 40, page: params[:page])
      else
        @users = User.search(params[:search]).paginate(per_page: 40, page: params[:page])
      end
    end
  end

  def show
    @page = "general"
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
    @user = User.new
    @user.profile = Profile.new
    @user.lastip = request.env['REMOTE_ADDR']
    @user.can_create? cuser
  end

  def edit
    raise AccessError unless @user.can_update? cuser
  end

  def create
    @user = User.new(User.params(params, cuser, "create"))
    @user.lastip = request.env['REMOTE_ADDR']

    raise AccessError unless @user.can_create? cuser

    if @user.valid? and @user.save
      redirect_to action: :show, id: @user.id
      save_session @user
    else
      render :new
    end
  end

  def update
    raise AccessError unless @user.can_update? cuser  
    # FIXME: use permit
    params[:user].delete(:username) unless @user.can_change_name? cuser
    if @user.update_attributes(User.params(params, cuser, "update"))
      flash[:notice] = t(:users_update)
      redirect_to_back
    else
      render :edit
    end
  end

  def destroy
    raise AccessError unless @user.can_destroy? cuser
    @user.destroy
    redirect_to users_url
  end

  def callback
    @user = User.focfah(auth_hash, request.ip)
    login_user(@user)
    if @user.created_at > (Time.zone.now - 1.week)
      flash[:notice] << t(:users_signup_steam)
      render :edit
    else
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
    if request.post?
      if (user1 = User.where(username: params[:username], email: params[:email]).first) && user1.send_new_password
        flash[:notice] = t(:passwords_sent)
      else
        flash[:error] = t(:incorrect_information)
      end
    end
  end

  private

  def get_user
    @user = User.find(params[:id])
  end

  def login_user(user)
    if user.banned? Ban::TYPE_SITE
      flash[:error] = t(:accounts_locked)
    else
      flash[:notice] = "%s (%s)" % [t(:login_successful), user.password_hash_s]
      # FIXME: this doesn't work because model is saved before
      flash[:notice] << " \n%s" % I18n.t(:password_md5_scrypt) if user.password_hash_changed?
      save_session user
    end
  end

  def save_session user
    session[:user] = user.id
    user.lastip = request.ip
    user.lastvisit = Time.now.utc
    user.save!
  end

  def auth_hash
    request.env['omniauth.auth']
  end
end
