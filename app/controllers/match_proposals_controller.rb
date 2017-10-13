class MatchProposalsController < ApplicationController
  before_filter :get_match
  def index
    raise AccessError unless @match.user_in_match?(cuser)
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
      # TODO: send message to teamleaders of opposite team
      msg = Message.new
      msg.sender_type = 'System'
      msg.recipient_type = 'Team'
      msg.title = 'New Scheduling Proposal'
      recipient = @match.get_opposing_team(cuser.team)
      msg.recipient = recipient
      msg.text = "There is a new scheduling proposal for your match against #{recipient.name}.\n" \
        "Find it [url=#{match_proposals_path(@match)}]here[/url]"
      msg.save
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
    new_status = params[:match_proposal][:status]
    curr_status = proposal.status
    status_updated = curr_status != new_status
    proposal.status = new_status
    if proposal.save

      if status_updated
        msg = Message.new
        msg.sender_type = 'System'
        msg.recipient_type = 'Team'
        msg.title = 'New Scheduling Proposal'
        recipient = @match.get_opposing_team(cuser.team)
        msg.recipient = recipient
        msg.text = message_text(new_status)
        msg.save if msg.text
      end

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

  def message_text(new_status)
    case new_status
    when MatchProposal::STATUS_CONFIRMED
      "A scheduling proposal for your match against #{recipient.name} was confirmed!.\n" \
      "Find it [url=#{match_proposals_path(@match)}]here[/url]"
    when MatchProposal::STATUS_REJECTED
      "A scheduling proposal for your match against #{recipient.name} was rejected!.\n" \
      "Find it [url=#{match_proposals_path(@match)}]here[/url]"
    when MatchProposal::STATUS_REVOKED
      "A scheduling proposal for your match against #{recipient.name} was revoked!.\n" \
      "Find it [url=#{match_proposals_path(@match)}]here[/url]"
    when MatchProposal::STATUS_DELAYED
      "Delaying for your match against #{recipient.name} was permitted!.\n" \
      "Schedule a new time as soon as possible [url=#{match_proposals_path(@match)}]here[/url]"
    else
      false # Should not happen as transition to any other state is not allowed
    end
  end
end
