module Gathers
  class Broadcaster
    include ActionView::RecordIdentifier

    def self.call(gather)
      new(gather).call
    end

    def initialize(gather)
      @gather = gather
    end

    def call
      @gather.bump_version!
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
      renderer = renderer.new(session: { user: user.id }) if user
      gatherer = user ? @gather.gatherers.of_user(user).first : nil

      renderer.render(
        partial: 'gathers/frame',
        assigns: { gather: @gather, gatherer: gatherer }
      )
    end
  end
end
