class MatchProposalsController < ApplicationController

  def index
    @match = Match.find(params[:match_id])
  end

  def new
    match = Match.find(params[:match_id])
    @proposal = MatchProposal.new(match: match)
    raise AccessError unless @proposal.can_create? cuser
  end

  def create
    match = Match.find(params[:match_id])
    @proposal = MatchProposal.new(match: match)
    raise AccessError unless @ban.can_create? cuser
    @proposal.team = cuser.team
    @proposal.status = MatchProposal::STATUS_PENDING
    @proposal.proposed_time = params[:match_proposal][:proposed_time]

    if @proposal.save
      flash[:notice] = 'Created new proposal'
      redirect_to(match)
    else
      render :new
    end
  end

  def update
  end

end
