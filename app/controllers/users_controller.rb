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
        @page = params[:page] if self.PAGES.include?(params[:page])
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
      @user.profile = Profile.new
      @user.profile.user = @user
      @user.profile.save!
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

  # FIXME: maybe move to session controller
  def login
    if params[:login] && (u = User.authenticate(params[:login]))
      if u.banned? Ban::TYPE_SITE
        flash[:notice] = t(:accounts_locked)
      else
        flash[:notice] = t(:login_successful)
        save_session u
      end
    else
      flash[:error] = t(:login_unsuccessful)
    end
    # FIXME: check return on rails 6
    if session[:return_to]
      return_to
    else
      redirect_to_back
    end
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

  def save_session user
    session[:user] = user.id
    user.lastip = request.ip
    user.lastvisit = Time.now.utc
    user.save
  end
end
