# frozen_string_literal: true

# Pushes a "your gather is starting" notification to the gather's players who opted in.
class GatherStartedPushJob
  include Sidekiq::Job

  sidekiq_options queue: :default, retry: 2

  def perform(gather_id)
    gather = Gather.find_by(id: gather_id)
    return unless gather

    user_ids = User.joins(:gatherers, :profile)
                   .where(gatherers: { gather_id: gather.id }, profiles: { notify_push_gather: true })
                   .distinct.pluck(:id)

    delivered = PushNotifications::Deliver.call(user_ids: user_ids, payload: payload(gather))
    Rails.logger.info("[GatherStartedPushJob] gather=#{gather.id} opted_in=#{user_ids.size} delivered=#{delivered}")
  end

  private

  def payload(gather)
    {
      title: 'Gather is starting!',
      body: 'Teams are being picked now. Get back to the gather page.',
      tag: "gather-#{gather.id}",
      url: Rails.application.routes.url_helpers.gather_path(gather)
    }
  end
end
