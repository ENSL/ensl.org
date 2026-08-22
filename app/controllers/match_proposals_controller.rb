# frozen_string_literal: true

class MatchProposalsController < ApplicationController
  before_action :load_match

  def index
    raise AccessError unless cuser&.admin? || @match.user_in_match?(cuser)
  end

  def new
    # Don't allow creation of new proposals if there is a confirmed one already
    if @match.confirmed_proposal?
      flash[:error] = 'Cannot create a new proposal if there is already a confirmed one'
      return redirect_to(match_proposals_path(@match))
    end
    @proposal = MatchProposal.new(match: @match)
    raise AccessError unless @proposal.can_create? cuser
  end

  def create
    @proposal = build_match_proposal
    raise AccessError unless @proposal.can_create? cuser

    @proposal.assign_attributes(team: cuser.active_team, status: MatchProposal::STATUS_PENDING, actor: cuser)
    return handle_match_proposal_create_success if @proposal.save

    render :new
  end

  def update
    raise AccessError unless request.xhr? # Only respond to ajax requests

    proposal = find_match_proposal
    return render_proposal_missing unless proposal

    proposal_params = MatchProposal.params(params, cuser)
    return render_proposal_forbidden(proposal_params[:status].to_i) unless proposal.can_update?(cuser, proposal_params)

    return render_proposal_error unless update_match_proposal(proposal, proposal_params)

    render_proposal_success(proposal)
  end

  private

  def load_match
    @match = Match.find params[:match_id]
  end

  def build_match_proposal
    MatchProposal.new(MatchProposal.params(params, cuser)).tap do |proposal|
      proposal.match = @match
    end
  end

  def handle_match_proposal_create_success
    flash[:notice] = 'Created new proposal'
    redirect_to(match_proposals_path(@match))
  end

  def find_match_proposal
    @match.match_proposals.find_by(id: params[:id])
  end

  def update_match_proposal(proposal, proposal_params)
    proposal.actor = cuser
    proposal.update(proposal_params)
  end

  def render_proposal_success(proposal)
    name = proposal.status_name
    render json: { status: name, message: "Successfully updated status to #{name}" }, status: :accepted
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
    render json: { error: { code: 500, message: 'Something went wrong! Please try again.' } },
           status: :internal_server_error
  end
end
