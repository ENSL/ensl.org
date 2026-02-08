module Gathers
  class CastVote
    include Exceptions

    def self.call(actor:, params:)
      new(actor: actor, params: params).call
    end

    def initialize(actor:, params:)
      @actor = actor
      @params = params
    end

    def call
      vote = Vote.new(@params)
      vote.user = @actor
      raise AccessError unless vote.can_create?(@actor)

      vote.save!
      gather = vote.votable.gather
      # Broadcaster handles version management via bump_version! which uses pessimistic locking
      Broadcaster.call(gather)
      Result.new(gather: gather, vote: vote)
    rescue StandardError => e
      Result.new(vote: vote, error: e)
    end
  end
end
