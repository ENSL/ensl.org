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

    if @proposal.save
      flash[:notice] = 'Created new proposal'
      redirect_to(match_proposals_path(@match))
    else
      render :new
    end
  end

  def update
    raise AccessError unless @match.can_make_proposal?(cuser)
    @proposal = MatchProposal.find(params[:id])
    @proposal.status = params[:match_proposal][:status]
    if @proposal.save
      action = case @proposal.status
                 when MatchProposal::STATUS_CONFIRMED
                   "Confirmed Proposal for #{Time.use_zone(view_context.timezone_offset) { @proposal.proposed_time.strftime('%d %B %y %H:%M %Z') }}"
                 when MatchProposal::STATUS_REJECTED
                   "Rejected Proposal for #{Time.use_zone(view_context.timezone_offset) { @proposal.proposed_time.strftime('%d %B %y %H:%M %Z') }}"
                 else
                   "Smthn went wrong"
               end
      flash[:notice] = action
    else
      flash[:notice] = "Error"
    end
    redirect_to(match_proposals_path(@match))
  end

private
  def get_match
    @match = Match.find params[:match_id]
  end
end
