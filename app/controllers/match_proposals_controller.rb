class MatchProposalsController < ApplicationController
  def index
    @match = Match.find(params[:match_id])
  end

  def new
  end

  def create
  end
end
