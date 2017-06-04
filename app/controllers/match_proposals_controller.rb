class MatchProposalsController < ApplicationController
  before_filter :get_match
  def index
  end

  def new
    @proposal = MatchProposal.new
    @proposal.match = @match
    raise AccessError unless @proposal.can_create? cuser
  end

  def create
    @proposal = MatchProposal.new(params[:match_proposal])
    @proposal.match = @match
    raise AccessError unless @proposal.can_create? cuser
    @proposal.team = cuser.team
    @proposal.status = MatchProposal::STATUS_PENDING

    if @proposal.save!
      flash[:notice] = 'Created new proposal'
      redirect_to(@match)
    else
      render :new
    end
  end

  def update
  end

private
  def get_match
    @match = Match.find params[:match_id]
  end
end
