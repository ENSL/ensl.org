module Gathers
  class Broadcaster
    include ActionView::RecordIdentifier

    def self.call(gather, skip_user_ids: [])
      new(gather, skip_user_ids: skip_user_ids).call
    end

    def initialize(gather, skip_user_ids: [])
      @gather = gather
      @skip_user_ids = Array(skip_user_ids).compact
    end

    def call
      @gather.reload
      @gather.bump_version!
      # In test, skip all ActionCable HTML renders. Every join/vote/pick would
      # otherwise render N+1 full partials (O(n²) across 12 joins). The version
      # bump alone is sufficient: gather_sync_controller.js detects the mismatch
      # and reloads the frame via its poll interval, giving each session fresh,
      # user-specific content through a normal GET /gathers/:id.
      return if Rails.env.test?

      broadcast_for_guest
      broadcast_for_users
    end

    private

    def broadcast_for_guest
      Turbo::StreamsChannel.broadcast_replace_to(
        @gather,
        target: dom_id(@gather, :frame),
        html: render_for(nil)
      )
    end

    def broadcast_for_users
      user_ids = @gather.gatherers.where.not(user_id: nil).distinct.pluck(:user_id)
      user_ids -= @skip_user_ids if @skip_user_ids.any?
      User.where(id: user_ids).find_each do |user|
        Turbo::StreamsChannel.broadcast_replace_to(
          [@gather, user],
          target: dom_id(@gather, :frame),
          html: render_for(user)
        )
      end
    end

    def render_for(user)
      renderer = ApplicationController.renderer
      gatherer = user ? @gather.gatherers.of_user(user).first : nil

      renderer.render(
        partial: 'gathers/frame',
        assigns: { gather: @gather, gatherer: gatherer, cuser: user }
      )
    end
  end
end
