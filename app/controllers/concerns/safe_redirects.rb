# frozen_string_literal: true

# Redirect helpers shared across controllers: capturing/restoring the pre-auth
# destination URL, and guarding against open-redirect vulnerabilities when
# following a stored or user-supplied destination.
module SafeRedirects
  extend ActiveSupport::Concern

  included do
    helper_method :return_here, :safe_url_for
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
    return redirect_to('/') if addr.blank?

    uri = URI.parse(addr)
    return redirect_to('/') unless uri.host.nil? || uri.host == request.host

    redirect_to_recognized_path(uri.request_uri)
  rescue StandardError
    redirect_to('/')
  end

  # Resolve a same-host path through the router, refusing error pages.
  def redirect_to_recognized_path(path)
    route = Rails.application.routes.recognize_path(path)
    if route[:controller] == 'errors' || path.match?(%r{\A/(403|404|422|500)\b})
      redirect_to('/')
    else
      redirect_to path
    end
  rescue StandardError
    flash[:notice] = t(:invalid_message) if respond_to?(:flash)
    redirect_to('/')
  end

  # Return a safe URL (allow only http(s) or relative paths). Returns '#' if unsafe.
  def safe_url_for(url)
    SafeUrl.sanitize(url)
  end
end
