# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include Exceptions
  include ActionView::RecordIdentifier
  include ResourceResponses

  helper :all
  helper_method :cuser, :strip, :return_here
  helper_method :error_container_id_for, :error_wrapper_id_for

  helper_method :safe_url_for

  before_action :update_user
  before_action :set_controller_and_action_names
  before_action :set_paper_trail_whodunnit

  # Omniauth has its own CSRF handling for the callback endpoint.
  protect_from_forgery with: :exception
  skip_before_action :verify_authenticity_token, only: [:callback]

  respond_to :html, :js

  def emoji_shortcodes
    entries = Emoji.all.flat_map do |emoji|
      emoji.aliases.map do |emoji_alias|
        {
          key: emoji_alias,
          value: ":#{emoji_alias}:",
          emoji: emoji.raw
        }
      end
    end

    render json: entries
  end

  def cuser
    return @cuser if defined?(@cuser) && @cuser

    user_id = nil
    begin
      user_id = session[:user]
    rescue StandardError
      user_id = nil
    end

    @cuser = User.find(user_id) if user_id
    @cuser
  rescue StandardError
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

  def permitted_webauthn_credential_params
    params.require(:credential).permit(
      :id,
      :rawId,
      :type,
      :authenticatorAttachment,
      clientExtensionResults: {},
      response: [
        :attestationObject,
        :authenticatorData,
        :clientDataJSON,
        :publicKey,
        :publicKeyAlgorithm,
        :signature,
        :userHandle,
        { transports: [] }
      ]
    ).to_h
  end

  rescue_from AccessError do |_exception|
    render 'errors/403', status: :forbidden, layout: 'errors'
  end

  rescue_from Exceptions::UserRegistrationReq do |_exception|
    render plain: I18n.t(:user_registration_required), status: :forbidden
  end

  rescue_from ActiveRecord::RecordNotFound do |_exception|
    respond_to do |format|
      format.html { render 'errors/404', status: :not_found, layout: 'errors' }
      format.any { head :not_found }
    end
  end

  rescue_from ActionController::InvalidAuthenticityToken do |_exception|
    Rails.logger.error(
      "CSRF failure path=#{request.fullpath} method=#{request.request_method} " \
      "ip=#{request.ip} referer=#{request.referer.to_s.inspect} " \
      "ua=#{request.user_agent.to_s.inspect} params=#{request.filtered_parameters.inspect}"
    )

    error_message = I18n.t(:csrf_retry, default: 'Your page expired while updating. Please try again.')
    respond_to do |format|
      format.turbo_stream do
        flash.now[:error] = error_message
        render turbo_stream: turbo_stream.replace('notification', partial: 'application/messages'),
               status: :unprocessable_content
      end
      format.html do
        flash[:error] = error_message
        redirect_back fallback_location: root_path
      end
      format.any { head :unprocessable_content }
    end
  end

  rescue_from ActionController::InvalidCrossOriginRequest do |_exception|
    Rails.logger.warn(
      "Cross-origin JS blocked path=#{request.fullpath} method=#{request.request_method} " \
      "ip=#{request.ip} referer=#{request.referer.to_s.inspect} " \
      "ua=#{request.user_agent.to_s.inspect}"
    )
    head :not_acceptable unless performed?
  end

  unless Rails.env.production?
    rescue_from Error do |exception|
      render inline: exception.message.to_s, layout: true, status: :internal_server_error
    end
  end

  # Handle optimistic locking conflicts in all environments including production
  rescue_from ActiveRecord::StaleObjectError do |_exception|
    Rails.logger.warn("StaleObjectError: path=#{request.fullpath} user=#{cuser&.id} ip=#{request.ip}")
    flash[:error] = t(:application_stale)
    redirect_to_back
  end

  private

  def error_container_id_for(record)
    "#{dom_id(record)}_errors"
  end

  def error_wrapper_id_for(record)
    "#{dom_id(record)}_errors_wrapper"
  end

  def respond_with_validation_errors(record, template:)
    flash.now[:alert] = I18n.t(:please_fix_errors, default: 'Please fix the errors below.')
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.update(
            error_wrapper_id_for(record),
            partial: 'shared/errors',
            locals: { messages: record.errors.full_messages, container_id: error_container_id_for(record) }
          ),
          turbo_stream.replace('notification', partial: 'application/messages')
        ], status: :unprocessable_content
      end
      format.html { render template, status: :unprocessable_content }
    end
  end

  def update_user
    user = cuser
    return unless user

    Time.zone = user.time_zone
    user.touch_last_visit_if_stale!

    flash[:notice] = 'Your profile has been removed and recreated.' if user.ensure_profile!

    return unless user.banned? Ban::TYPE_SITE

    session[:user] = nil
    @cuser = nil
  end

  def set_controller_and_action_names
    @current_controller = controller_name
    @current_action     = action_name
  end

  def user_for_paper_trail
    cuser&.id
  end
end
