class UsersController < ApplicationController
  before_action :get_user, only: [:show, :history, :popup, :agenda, :edit, :update, :destroy]
  respond_to :html, :js

  def index
    search = params[:search]
    if search && search.match(/^ip:(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})$/) && cuser && cuser.admin?
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
        pages = ["general", "favorites", "computer", "articles", "movies", "teams", "matches", "predictions", "comments"]
        if pages.include?(params[:page])
          @page = params[:page]
        end
      end
      format.html {}
    end
  end

  def agenda
    @teamer = Teamer.new
    @teamer.user = @user
  end

  def history
    raise AccessError unless cuser and cuser.admin?
  end

  def popup
    render layout: false
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
    # FIXME: move to model
    @user.lastvisit = Date.today
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

  def login
    return unless request.post?

    if u = User.authenticate(params[:login][:username].downcase, params[:login][:password])
      raise Error, t(:accounts_locked) if u.banned? Ban::TYPE_SITE

      flash[:notice] = t(:login_successful)
      save_session u

      if session[:return_to]
        return_to
      else
        redirect_to_back
      end
    else
      flash[:error] = t(:login_unsuccessful)
      redirect_to_back
    end
  end

  def logout
    if request.post?
      session[:user] = nil
      flash[:notice] = t(:login_out)
      redirect_to :root
    end
  end

  def forgot
    if request.post?
      if u = User.first(:conditions => {:username => params[:username], :email => params[:email]}) and u.send_new_password
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
    user.lastvisit = DateTime.now
    user.save()
  end
end
