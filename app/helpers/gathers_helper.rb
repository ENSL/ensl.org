module GathersHelper
  def render_gather
    if @gather.status == Gather::STATE_RUNNING
      if @gather.is_full? and !@gather.is_ready? and @gather.captain1 != @gatherer and @gather.captain2 != @gatherer
        headers['Gather'] = 'full'
      else
        headers['Gather'] = 'running'
      end

      render partial: 'running', layout: false
    elsif @gather.status == Gather::STATE_VOTING
      if @gatherer and @gather.gatherer_votes.first(conditions: { user_id: cuser.id })
        headers['Gather'] = 'voted'
      else
        headers['Gather'] = 'voting'
      end

      render partial: 'voting', layout: false
    elsif @gather.status == Gather::STATE_PICKING or @gather.status == Gather::STATE_FINISHED
      headers['Gather'] = 'picking'

      render partial: 'picking', layout: false
    end
  end
end
