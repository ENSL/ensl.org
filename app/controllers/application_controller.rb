class ApplicationController < ActionController::Base
  include Exceptions

  helper :all
  helper_method :cuser, :strip, :return_here

  helper_method :safe_url_for

  before_action :update_user
  before_action :set_controller_and_action_names

  # Omniauth has its own CSRF handling for the callback endpoint.
  protect_from_forgery with: :exception
  skip_before_action :verify_authenticity_token, only: [:callback]

  respond_to :html, :js

  def cuser
    @cuser ||= User.find(session[:user])
  # Don't error if the user is missing.
  rescue StandardError
    session[:user] = nil
    @cuser = nil
  end

  def return_here
    return unless request.get? && request.format.html?

    session[:return_to] = request.url
  end

  def return_to
    addr = session[:return_to]
    session[:return_to] = nil
    safe_redirect_to(addr)
  end

  def return_back
    if session[:return_to]
      return_to
    else
      redirect_back fallback_location: '/'
    end
  rescue StandardError
    redirect_to '/'
  end

  def redirect_to_back
    redirect_back fallback_location: '/'
  rescue StandardError
    redirect_to '/'
  end

  def redirect_to_home
    redirect_to controller: 'articles', action: 'news_index'
  end

  # Safe redirect helper: only allow redirects to same-host or relative paths.
  def safe_redirect_to(addr)
    return redirect_to('/') unless addr.present?

    begin
      uri = URI.parse(addr)
      # Allow relative URLs or same-host absolute URLs
      if uri.host.nil? || uri.host == request.host
        path = uri.request_uri
        begin
          Rails.application.routes.recognize_path(path)
          redirect_to path
        rescue StandardError
          flash[:notice] = t(:invalid_message) if respond_to?(:flash)
          redirect_to('/')
        end
      else
        redirect_to('/')
      end
    rescue StandardError
      redirect_to('/')
    end
  end

  # Return a safe URL (allow only http(s) or relative paths). Returns '#' if unsafe.
  def safe_url_for(url)
    return '#' unless url.present?

    begin
      uri = URI.parse(url.to_s)
      if uri.scheme.nil? && uri.path.present?
        # relative path
        return uri.to_s
      end
      return uri.to_s if %w[http https].include?(uri.scheme)
    rescue StandardError
      return '#'
    end
    '#'
  end

  rescue_from AccessError do |_exception|
    render 'errors/403', status: :forbidden, layout: 'errors'
  end

  unless Rails.env.production?
    rescue_from Error do |exception|
      render inline: exception.message.to_s, layout: true, status: :internal_server_error
    end

    rescue_from ActiveRecord::StaleObjectError do |_exception|
      render inline: t(:application_stale), status: :conflict
    end

    rescue_from ActiveRecord::RecordNotFound do |_exception|
      # Correct template reference: 'errors/404' (not 'errors/404.html')
      render 'errors/404', status: :not_found, layout: 'errors'
    end
  end

  private

  # FIXME: move to model
  def update_user
    return unless cuser

    Time.zone = cuser.time_zone
    cuser.update_attribute :lastvisit, Time.now.utc if cuser&.lastvisit&.< 2.minutes.ago.utc

    # FIXME: there is a bug in steam auth that causes nil profile
    unless cuser.profile&.present?
      flash[:notice] = 'Your profile has been removed and recreated.'
      cuser.build_profile
      cuser.save
    end

    return unless cuser.banned? Ban::TYPE_SITE

    session[:user] = nil
    @cuser = nil
  end

  def set_controller_and_action_names
    @current_controller = controller_name
    @current_action     = action_name
  end
end
