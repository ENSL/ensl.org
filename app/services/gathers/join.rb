# frozen_string_literal: true

module Gathers
  class Join
    def self.call(actor:, params:)
      new(actor: actor, params: params).call
    end

    def initialize(actor:, params:)
      @actor = actor
      @params = params
    end

    def call
      gatherer = Gatherer.new(@params)

      Gather.transaction do
        Gatherer.transaction do
          gatherer.gather.lock!
          raise AccessError unless gatherer.can_create?(@actor, @params)

          gatherer.save!
        end
      end

      Broadcaster.call(gatherer.gather, skip_user_ids: [@actor&.id])
      Result.new(gather: gatherer.gather, gatherer: gatherer)
    rescue StandardError => e
      Result.new(gather: gatherer&.gather, gatherer: gatherer, error: e)
    end
  end
end
