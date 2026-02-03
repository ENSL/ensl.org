module Gathers
  class CaptainPick
    def self.call(actor:, gather:, player_id:)
      new(actor: actor, gather: gather, player_id: player_id).call
    end

    def initialize(actor:, gather:, player_id:)
      @actor = actor
      @gather = gather
      @player_id = player_id
    end

    def call
      gatherer = @gather.gatherers.find(@player_id)
      raise AccessError unless gatherer.can_update?(@actor, { team: gatherer.team })

      Gatherer.transaction do
        Gather.transaction do
          gatherer.update!(team: @gather.turn)
          @gather.reload
        end
      end

      Broadcaster.call(@gather)
      Result.new(gather: @gather, gatherer: gatherer)
    rescue StandardError => e
      Result.new(gather: @gather, gatherer: gatherer, error: e)
    end
  end
end
