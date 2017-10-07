class MatchProposalsController < ApplicationController
  before_filter :get_match
  def index
    raise AccessError unless @match.user_in_match?(cuser)
  end

  def new
    mp = MatchProposal.confirmed_for_match(@match).first
    if mp
      flash[:danger] = 'Cannot create a new proposal aslong as there already is a confirmed one'
      redirect_to(match_proposals_path(@match))  && return
    end
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
    raise AccessError unless request.xhr? # Only respond to ajax requests
    rjson = {}
    proposal = MatchProposal.find(params[:id])
    unless proposal
      rjson[:error] = {
        code: 404,
        message: "No proposal with id #{params[:id]}"
      }
      render(json: rjson, status: :not_found) && return
    end
    unless proposal.can_update?(cuser, params[:match_proposal])
      rjson[:error] = {
        code: 403,
        message: "You are not allowed to update the state to #{MatchProposal.status_strings[params[:match_proposal][:status].to_i]}"
      }
      render(json: rjson, status: :forbidden) && return
    end
    proposal.status = params[:match_proposal][:status]
    if proposal.save
      rjson[:status] = MatchProposal.status_strings[proposal.status]
      rjson[:message] = "Successfully updated status to #{MatchProposal.status_strings[proposal.status]}"
      render(json: rjson, status: :accepted)
    else
      rjson[:error] = {
        code: 500,
        message: 'Something went wrong! Please try again.'
      }
      render(json: rjson, status: 500)
    end
  end

private
  def get_match
    @match = Match.find params[:match_id]
  end
end
