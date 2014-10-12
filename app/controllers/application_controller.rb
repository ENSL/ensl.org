class ApplicationController < ActionController::Base
  include Exceptions

  helper :all
  helper_method :cuser, :strip, :return_here

  before_filter :update_user
  before_filter :set_controller_and_action_names

  protect_from_forgery
  respond_to :html, :js

  def cuser
    @cuser ||= User.find(session[:user]) if session[:user]
  end

  def return_here
    session[:return_to] = request.url
  end

  def return_to
    addr = session[:return_to]
    session[:return_to] = nil
    redirect_to addr
  end

  def redirect_to_back
    if request.env["HTTP_REFERER"]
      redirect_to request.env["HTTP_REFERER"]
    else
      redirect_to "/"
    end
  rescue
    redirect_to "/"
  end

  def redirect_to_home
    redirect_to controller: "articles", action: "news_index"
  end

  rescue_from AccessError do |exception|
    render 'errors/403', status: 403, layout: 'errors'
  end

  rescue_from Error do |exception|
    render text: exception.message, layout: true
  end

  rescue_from ActiveRecord::StaleObjectError do |exception|
    render text: t(:application_stale)
  end

  rescue_from ActiveRecord::RecordNotFound do |exception|
    render :template => 'errors/404.html', :status => :not_found, :layout => 'errors'
  end

  private

  def update_user
    if cuser
      Time.zone = cuser.time_zone
      cuser.update_attribute :lastvisit, DateTime.now if cuser.lastvisit < 2.minutes.ago

      if cuser.banned? Ban::TYPE_SITE
        session[:user] = nil
        @cuser = nil
      end
    end
  end

  def set_controller_and_action_names
    @current_controller = controller_name
    @current_action     = action_name
  end
end
