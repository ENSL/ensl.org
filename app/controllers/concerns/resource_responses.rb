# frozen_string_literal: true

# Shared helpers for the create/update response patterns that repeat across
# resource controllers: persist a record, set a translated flash message, and
# either redirect or re-render the form.
module ResourceResponses
  extend ActiveSupport::Concern

  private

  # Persist via the given block; on success set a notice and redirect to
  # +location+, otherwise set a flash.now error and re-render +template+.
  #
  #   save_and_respond(@week, notice: :weeks_create,
  #                           location: edit_contest_path(@week.contest),
  #                           template: :new) { @week.save }
  def save_and_respond(record, notice:, location:, template:, **render_options)
    if yield
      flash[:notice] = flash_message(notice)
      redirect_to location
    else
      flash.now[:error] = record.errors.full_messages.to_sentence.presence || t(:error)
      render template, status: :unprocessable_content, **render_options
    end
  end

  # Persist via the given block and set a notice/error flash. The caller is
  # responsible for the redirect, which is performed regardless of outcome.
  #
  #   save_and_flash(@lock, notice: :topics_locked) { @lock.save }
  #   redirect_to_back
  def save_and_flash(record, notice:)
    if yield
      flash[:notice] = flash_message(notice)
    else
      flash[:error] = record.errors.full_messages.to_sentence
    end
  end

  def flash_message(message)
    case message
    when Symbol
      t(message)
    when String
      I18n.exists?(message) ? t(message) : message
    when Array
      action, resource, type = message
      flash_action_message(action, resource, type: type || :notice)
    when Hash
      flash_action_message(message.fetch(:action), message.fetch(:resource), type: message.fetch(:type, :notice))
    else
      message
    end
  end

  def flash_action_message(action, resource, type: :notice)
    t("flash.actions.#{action}.#{type}", resource_name: human_resource_name(resource))
  end

  def human_resource_name(resource)
    if resource.is_a?(Class) && resource.respond_to?(:model_name)
      resource.model_name.human
    elsif resource.class.respond_to?(:model_name)
      resource.class.model_name.human
    else
      resource.to_s.humanize
    end
  end
end
