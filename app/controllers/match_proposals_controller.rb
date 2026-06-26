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

    @proposal.assign_attributes(team: cuser.team, status: MatchProposal::STATUS_PENDING)
    if @proposal.save
      recipient = @match.get_opposing_team(cuser.team)
      msg_text = "There is a new scheduling proposal for your match against #{cuser.team.name}.\n" \
                 "Find it [url=#{match_proposals_path(@match)}]here[/url]"

      send_message_to_opp_team(msg_text, 'New Scheduling Proposal', recipient)

      flash[:notice] = 'Created new proposal'
      redirect_to(match_proposals_path(@match))
    else
      render :new
    end
  end

  def update
    raise AccessError unless request.xhr? # Only respond to ajax requests

    result = MatchProposal.update_status_for_match(
      match: @match,
      proposal_id: params[:id],
      raw_params: params,
      actor: cuser
    )

    return render_status_update_error(result) unless result.success?

    render_status_update_success(result)
  end

  private

  def load_match
    @match = Match.find params[:match_id]
  end

  def message_text(new_status)
    case new_status
    when MatchProposal::STATUS_CONFIRMED
      "A scheduling proposal for your match against [b]#{cuser.team.name}[/b] was confirmed!.\n" \
      "Find it [url=#{match_proposals_path(@match)}]here[/url]"
    when MatchProposal::STATUS_REJECTED
      "A scheduling proposal for your match against [b]#{cuser.team.name}[/b] was rejected!.\n" \
      "Find it [url=#{match_proposals_path(@match)}]here[/url]"
    when MatchProposal::STATUS_REVOKED
      "A scheduling proposal for your match against [b]#{cuser.team.name}[/b] was revoked!.\n" \
      "Find it [url=#{match_proposals_path(@match)}]here[/url]"
    when MatchProposal::STATUS_DELAYED
      "Delaying for your match against [b]#{cuser.team.name}[/b] was permitted!.\n" \
      "Schedule a new time as soon as possible [url=#{match_proposals_path(@match)}]here[/url]"
    else
      false # Should not happen as transition to any other state is not allowed
    end
  end

  def send_message_to_opp_team(text, title, recipient_team)
    msg = Message.new(
      sender_type: 'System',
      recipient_type: 'Team',
      title: title,
      recipient: recipient_team,
      text: text
    )
    msg.save if text
  end

  def render_status_update_error(result)
    render json: {
      error: {
        code: Rack::Utils.status_code(result.http_status),
        message: result.error_message
      }
    }, status: result.http_status
  end

  def render_status_update_success(result)
    if result.status_updated
      recipient = @match.get_opposing_team(cuser.team)
      msg_text = message_text(result.new_status)
      send_message_to_opp_team(msg_text, 'Scheduling Proposal Update', recipient)
    end

    render json: {
      status: result.proposal.status_name,
      message: result.proposal.status_update_message
    }, status: :accepted
  end
end
