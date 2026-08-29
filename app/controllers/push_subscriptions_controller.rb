# frozen_string_literal: true

# Stores/removes the browser Web Push endpoints a user opted in from, and keeps the
# permanent `notify_push_gather` profile preference in sync with them.
class PushSubscriptionsController < ApplicationController
  before_action :require_user!

  def create
    PushSubscription.register!(
      user: cuser,
      endpoint: subscription_params[:endpoint],
      p256dh_key: subscription_params.dig(:keys, :p256dh),
      auth_key: subscription_params.dig(:keys, :auth),
      user_agent: request.user_agent
    )
    cuser.profile&.update(notify_push_gather: true)

    render json: { enabled: true }
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_content
  end

  def destroy
    endpoint = params[:endpoint].to_s
    cuser.push_subscriptions.where(endpoint: endpoint).destroy_all if endpoint.present?
    cuser.profile&.update(notify_push_gather: false)

    render json: { enabled: false }
  end

  private

  def require_user!
    render json: { error: I18n.t(:user_registration_required) }, status: :forbidden unless cuser
  end

  def subscription_params
    params.require(:subscription).permit(:endpoint, keys: %i[p256dh auth])
  end
end
