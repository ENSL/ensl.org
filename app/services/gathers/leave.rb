# frozen_string_literal: true

module Gathers
  class Leave
    def self.call(actor:, gatherer:)
      new(actor: actor, gatherer: gatherer).call
    end

    def initialize(actor:, gatherer:)
      @actor = actor
      @gatherer = gatherer
    end

    def call
      raise AccessError unless @gatherer.can_destroy?(@actor)

      gather = @gatherer.gather
      Gather.transaction do
        gather.create_gather_activity key: 'gather.left', owner: @actor, recipient: @gatherer.user
        @gatherer.destroy!
      end
      Broadcaster.call(gather)
      Result.new(gather: gather)
    rescue StandardError => e
      Result.new(gather: @gatherer&.gather, gatherer: @gatherer, error: e)
    end
  end
end
