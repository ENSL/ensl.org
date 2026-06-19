# frozen_string_literal: true

module Gathers
  class Broadcaster
    include ActionView::RecordIdentifier

    # Set to true in feature specs to skip per-user HTML renders.
    # Version bump still occurs so gather_sync_controller.js reloads via polling.
    cattr_accessor :skip_broadcasts, default: false

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
      return if self.class.skip_broadcasts

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
