# frozen_string_literal: true

module Gathers
  class CaptainPick
    MAX_LOCK_RETRIES = 2

    def self.call(actor:, gather:, player_id:)
      new(actor: actor, gather: gather, player_id: player_id).call
    end

    def initialize(actor:, gather:, player_id:)
      @actor = actor
      @gather = gather
      @player_id = player_id
    end

    def call
      retries = 0

      begin
        gatherer = nil

        Gather.transaction do
          @gather.with_lock do
            @gather.reload
            gatherer = @gather.gatherers.lock.find(@player_id)
            raise AccessError unless gatherer.can_update?(@actor, { team: gatherer.team })

            @gather.create_gather_activity(
              key: 'gather.player_picked',
              owner: @actor,
              recipient: gatherer.user,
              parameters: { team: @gather.turn }
            )
            gatherer.update!(team: @gather.turn)
            @gather.reload
          end
        end

        Broadcaster.call(@gather)
        Result.new(gather: @gather, gatherer: gatherer)
      rescue ActiveRecord::LockWaitTimeout, ActiveRecord::Deadlocked
        retries += 1
        retry if retries <= MAX_LOCK_RETRIES

        Result.new(gather: @gather,
                   error: I18n.t(:gathers_busy_try_again,
                                 default: 'Gather is busy, please try again in a moment.'))
      rescue ActiveRecord::RecordNotFound
        Result.new(gather: @gather,
                   error: I18n.t(:gathers_player_unavailable,
                                 default: 'Selected player is no longer available to pick.'))
      rescue AccessError
        Result.new(gather: @gather,
                   error: I18n.t(:gathers_not_your_turn,
                                 default: 'It is no longer your turn to pick.'))
      end
    rescue StandardError => e
      Result.new(gather: @gather, error: e)
    end
  end
end
