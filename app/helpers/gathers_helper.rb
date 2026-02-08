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
end
