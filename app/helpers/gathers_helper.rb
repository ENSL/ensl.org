# frozen_string_literal: true

module GathersHelper
  def gather_current_user(gatherer = gatherer_from_context)
    gatherer&.user || cuser
  end

  def render_gather(gather = gather_from_context, gatherer = gatherer_from_context)
    return unless gather

    locals = { gather: gather, gatherer: gatherer }

    if gather.status == Gather::STATE_RUNNING
      headers['Gather'] = 'running'

      render partial: 'gathers/running', layout: false, locals: locals
    elsif gather.status == Gather::STATE_VOTING
      headers['Gather'] = gather_voting_header(gather, gatherer)

      render partial: 'gathers/voting', layout: false, locals: locals
    elsif [Gather::STATE_PICKING, Gather::STATE_FINISHED].include?(gather.status)
      headers['Gather'] = 'picking'

      render partial: 'gathers/picking', layout: false, locals: locals
    end
  end

  def gather_music_should_play?(gather = gather_from_context)
    user = gather_current_user
    return false unless gather && user
    return false unless gather.users.exists?(user.id)
    return false unless gather.status == Gather::STATE_VOTING

    !gather.gatherer_votes.where(user_id: user.id).exists? &&
      !gather.map_votes.where(user_id: user.id).exists? &&
      !gather.server_votes.where(user_id: user.id).exists?
  end

  def gather_archive_link(css_class = 'button tiny')
    link_to gathers_path, class: css_class, data: { turbo_frame: '_top' } do
      'Gather archive'
    end
  end

  # User-facing description of a gather's state for the header "signed up" badge.
  # Keeps the internal status names (running/voting/picking/finished) out of user copy.
  def gather_header_badge(gather)
    case gather.status
    when Gather::STATE_RUNNING
      { description: 'Lobby is still filling up, jump in!', icon: 'door-open',
        classes: 'bg-sky-600 hover:bg-sky-500 text-white' }
    when Gather::STATE_VOTING
      { description: 'Voting for maps & captains now', icon: 'square-poll-vertical',
        classes: 'bg-emerald-600 hover:bg-emerald-500 animate-pulse text-white' }
    when Gather::STATE_PICKING
      # The status column only flips to STATE_FINISHED once someone visits/polls the
      # gather page and triggers a refresh, so teams can be full well before that happens.
      if gather.picking_slot_available?
        { description: 'Captains are picking teams', icon: 'people-arrows',
          classes: 'bg-orange-600 hover:bg-orange-500 animate-pulse text-white' }
      else
        gather_finished_badge
      end
    when Gather::STATE_FINISHED
      gather_finished_badge
    end
  end

  def gather_from_context
    instance_variable_get(:@gather) || controller&.instance_variable_get(:@gather)
  end

  def gatherer_from_context
    instance_variable_get(:@gatherer) || controller&.instance_variable_get(:@gatherer)
  end

  private

  # Light background with dark text so it stays readable against the dark header,
  # unlike a mid gray which blends into it.
  def gather_finished_badge
    { description: 'Just finished, check the results', icon: 'flag-checkered',
      classes: 'bg-gray-100 hover:bg-white text-gray-900' }
  end

  def gather_voting_header(gather, gatherer)
    return 'voting' unless gatherer && cuser&.id
    return 'voting' unless gather.gatherer_votes.where(user_id: cuser.id).any?

    'voted'
  end
end
