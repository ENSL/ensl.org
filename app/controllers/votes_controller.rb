class VotesController < ApplicationController
  def create
    vote_params = Vote.params(params, cuser)

    if %w[Gatherer GatherMap GatherServer].include?(vote_params[:votable_type])
      result = Gathers::CastVote.call(actor: cuser, params: vote_params)
      if result.success?
        flash[:notice] = t(:votes_success)
        if result.gather
          redirect_to result.gather
        else
          redirect_to_back
        end
      else
        flash[:error] = result.error.to_s
        redirect_to_back
      end
    else
      @vote = Vote.new(vote_params)
      @vote.user = cuser
      raise AccessError unless @vote.can_create? cuser

      flash[:notice] = t(:votes_success) if @vote.save

      redirect_to_back
    end
  end
end
