# frozen_string_literal: true

class MatchProposalsController < ApplicationController
  before_action :load_match

  def index
    raise AccessError unless cuser&.admin? || @match.user_in_match?(cuser)
  end

  def new
    # Don't allow creation of new proposals if there is a confirmed one already
    if MatchProposal.exists?(
      match_id: @match.id,
      status: MatchProposal::STATUS_CONFIRMED
    )
      flash[:error] = 'Cannot create a new proposal if there is already a confirmed one'
      redirect_to(match_proposals_path(@match)) && return
    end
    @proposal = MatchProposal.new(match: @match)
    raise AccessError unless @proposal.can_create? cuser
  end

  def create
    @proposal = MatchProposal.new(MatchProposal.params(params, cuser))
    @proposal.match = @match
    raise AccessError unless @proposal.can_create? cuser

    @proposal.assign_attributes(team: cuser.team, status: MatchProposal::STATUS_PENDING, actor: cuser)
    if @proposal.save
      flash[:notice] = 'Created new proposal'
      redirect_to(match_proposals_path(@match))
    else
      render :new
    end
  end

  def update
    raise AccessError unless request.xhr? # Only respond to ajax requests

    proposal = @match.match_proposals.find_by(id: params[:id])
    return render_proposal_missing unless proposal

    proposal_params = MatchProposal.params(params, cuser)
    return render_proposal_forbidden(proposal_params[:status].to_i) unless proposal.can_update?(cuser, proposal_params)

    proposal.actor = cuser
    return render_proposal_error unless proposal.update(proposal_params)

    name = proposal.status_name
    render json: { status: name, message: "Successfully updated status to #{name}" }, status: :accepted
  end

  private

  def load_match
    @match = Match.find params[:match_id]
  end

  def render_proposal_missing
    render json: { error: { code: 404, message: "No proposal with id #{params[:id]}" } }, status: :not_found
  end

  def render_proposal_forbidden(new_status)
    render json: {
      error: {
        code: 403,
        message: "You are not allowed to update the state to #{MatchProposal.status_strings[new_status]}"
      }
    }, status: :forbidden
  end

  def render_proposal_error
    render json: { error: { code: 500, message: 'Something went wrong! Please try again.' } }, status: 500
  end
end
