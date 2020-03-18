class VotesController < ApplicationController
  def create
    @vote = Vote.new(Vote.params(params, cuser))
    @vote.user = cuser
    raise AccessError unless @vote.can_create? cuser

    if @vote.save
      flash[:notice] = t(:votes_success)
    end

    redirect_to_back
  end
end
