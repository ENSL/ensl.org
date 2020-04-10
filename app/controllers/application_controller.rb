class ApplicationController < ActionController::Base
  include Exceptions

  helper :all
  helper_method :cuser, :strip, :return_here

  before_action :update_user
  before_action :set_controller_and_action_names

  # Omniauth has its own CSRF
  protect_from_forgery :except => [:callback]
  
  respond_to :html, :js

  def cuser
    begin
      @cuser ||= User.find(session[:user]) 
    rescue
      session[:user] = nil
      @cuser = nil
    end
  end

  def return_here
    session[:return_to] = request.url
  end

  def return_to
    addr = session[:return_to]
    session[:return_to] = nil
    redirect_to addr
  end

  def return_back
    if session[:return_to]
      return_to
    elsif request.env["HTTP_REFERER"]
      redirect_to request.env["HTTP_REFERER"]
    else
      redirect_to "/"
    end
  rescue
    redirect_to "/"
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

  unless Rails.env.production?

    rescue_from AccessError do |exception|
      render 'errors/403', status: 403, layout: 'errors'
    end

    rescue_from Error do |exception|
      render text: exception.message, layout: true, status: 500
    end

    rescue_from ActiveRecord::StaleObjectError do |exception|
      render text: t(:application_stale)
    end

    rescue_from ActiveRecord::RecordNotFound do |exception|
      render :template => 'errors/404.html', :status => :not_found, :layout => 'errors'
    end
  end

  private

  # FIXME: move to model
  def update_user
    if cuser
      Time.zone = cuser.time_zone
      cuser.update_attribute :lastvisit, Time.now.utc if cuser&.lastvisit < 2.minutes.ago.utc

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
