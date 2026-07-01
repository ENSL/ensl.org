# frozen_string_literal: true

module GathersHelper
  def gather_current_user(gatherer = gatherer_from_context)
    gatherer&.user || cuser
  end

  def render_gather(gather = gather_from_context, gatherer = gatherer_from_context)
    if gather.status == Gather::STATE_RUNNING
      headers['Gather'] = 'running'

      render partial: 'gathers/running', layout: false
    elsif gather.status == Gather::STATE_VOTING
      headers['Gather'] = if gatherer && cuser&.id && gather.gatherer_votes.where(user_id: cuser.id).any?
                            'voted'
                          else
                            'voting'
                          end

      render partial: 'gathers/voting', layout: false
    elsif [Gather::STATE_PICKING, Gather::STATE_FINISHED].include?(gather.status)
      headers['Gather'] = 'picking'

      render partial: 'gathers/picking', layout: false
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

  def gather_from_context
    controller&.instance_variable_get(:@gather)
  end

  def gatherer_from_context
    controller&.instance_variable_get(:@gatherer)
  end
end
