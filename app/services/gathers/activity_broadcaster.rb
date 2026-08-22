# frozen_string_literal: true

module Gathers
  class ActivityBroadcaster
    def self.call(activity)
      gather = activity.trackable
      return unless gather.is_a?(Gather)

      stream = "shout_Gather_#{gather.id}"
      html = ApplicationController.render(partial: 'shoutmsgs/activity', locals: { activity: activity })
      Turbo::StreamsChannel.broadcast_append_to(stream, target: stream, html: html)
    rescue StandardError => e
      Rails.logger.error(
        "Gather activity broadcast failed: #{e.class}: #{e.message} -- activity_id=#{activity.id.inspect}"
      )
    end
  end
end
