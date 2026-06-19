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
      @gatherer.destroy!
      Broadcaster.call(gather)
      Result.new(gather: gather)
    rescue StandardError => e
      Result.new(gather: @gatherer&.gather, gatherer: @gatherer, error: e)
    end
  end
end
