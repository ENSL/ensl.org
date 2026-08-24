# frozen_string_literal: true

module Gathers
  class ActivityBroadcaster
    # Set to true in feature specs to skip per-activity HTML renders. Heavy
    # multi-session specs (e.g. the full gather flow) don't assert on the
    # activity feed, and rendering/broadcasting on every single vote and pick
    # adds render load on top of the already O(n) per-action Broadcaster
    # renders, which can exhaust the DB/Puma thread pool under CI load.
    cattr_accessor :skip_broadcasts, default: false

    def self.call(activity)
      return if skip_broadcasts

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
