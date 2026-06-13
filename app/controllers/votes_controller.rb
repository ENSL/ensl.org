class VotesController < ApplicationController
  GATHER_VOTABLE_TYPES = %w[Gatherer GatherMap GatherServer].freeze

  def create
    vote_params = Vote.params(params, cuser)

    return handle_gather_vote(vote_params) if gather_vote?(vote_params)

    @vote = Vote.new(vote_params)
    @vote.user = cuser
    raise AccessError unless @vote.can_create? cuser

    flash[:notice] = t(:votes_success) if @vote.save

    redirect_to_back
  end

  private

  def gather_vote?(vote_params)
    GATHER_VOTABLE_TYPES.include?(vote_params[:votable_type])
  end

  def handle_gather_vote(vote_params)
    result = Gathers::CastVote.call(actor: cuser, params: vote_params)

    if result.success?
      flash[:notice] = t(:votes_success)
      result.gather ? redirect_to(result.gather) : redirect_to_back
    else
      flash[:error] = result.error.to_s
      redirect_to_back
    end
  end
end
