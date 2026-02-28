module GathersHelper
  def gather_current_user
    @gatherer&.user || cuser
  end

  def render_gather
    if @gather.status == Gather::STATE_RUNNING
      headers['Gather'] = 'running'

      render partial: 'gathers/running', layout: false
    elsif @gather.status == Gather::STATE_VOTING
      headers['Gather'] = if @gatherer && cuser&.id && @gather.gatherer_votes.where(user_id: cuser.id).any?
                            'voted'
                          else
                            'voting'
                          end

      render partial: 'gathers/voting', layout: false
    elsif [Gather::STATE_PICKING, Gather::STATE_FINISHED].include?(@gather.status)
      headers['Gather'] = 'picking'

      render partial: 'gathers/picking', layout: false
    end
  end

  def gather_music_should_play?
    user = gather_current_user
    return false unless @gather && user
    return false unless @gather.users.exists?(user.id)
    return false if @gather.status == Gather::STATE_FINISHED

    !@gather.gatherer_votes.where(user_id: user.id).exists? &&
      !@gather.map_votes.where(user_id: user.id).exists? &&
      !@gather.server_votes.where(user_id: user.id).exists?
  end
end
