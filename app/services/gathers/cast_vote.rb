module Gathers
  class CastVote
    include Exceptions
    MAX_LOCK_RETRIES = 2

    def self.call(actor:, params:)
      new(actor: actor, params: params).call
    end

    def initialize(actor:, params:)
      @actor = actor
      @params = params
    end

    def call
      retries = 0
      vote = nil
      gather = nil

      begin
        Vote.transaction do
          vote = Vote.new(@params)
          vote.user = @actor

          gather = vote.votable&.respond_to?(:gather) ? vote.votable.gather : nil

          if gather
            gather.with_lock do
              raise AccessError unless vote.can_create?(@actor)

              vote.save!
            end
          else
            raise AccessError unless vote.can_create?(@actor)

            vote.save!
          end
        end

        # Broadcaster handles version management via bump_version! which uses pessimistic locking
        Broadcaster.call(gather) if gather
        Result.new(gather: gather, vote: vote)
      rescue ActiveRecord::LockWaitTimeout, ActiveRecord::Deadlocked
        retries += 1
        retry if retries <= MAX_LOCK_RETRIES

        Result.new(vote: vote,
                   error: I18n.t(:gathers_busy_try_again,
                                 default: 'Gather is busy, please try again in a moment.'))
      end
    rescue StandardError => e
      Result.new(vote: vote, error: e)
    end
  end
end
