# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include Exceptions
  include ActionView::RecordIdentifier
  include ResourceResponses
  include Authentication
  include SessionHygiene
  include SafeRedirects

  helper :all
  helper_method :strip
  helper_method :error_container_id_for, :error_wrapper_id_for

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

  def set_controller_and_action_names
    @current_controller = controller_name
    @current_action     = action_name
  end

  def user_for_paper_trail
    cuser&.id
  end
end
