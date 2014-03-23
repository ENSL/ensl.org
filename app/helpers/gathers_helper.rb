module GathersHelper
  def render_gather
    if @gather.status == Gather::STATE_RUNNING
      headers["Gather"] = "running"
      render :partial => "running", :layout => false
    elsif @gather.status == Gather::STATE_VOTING
      if @gatherer and @gather.gatherer_votes.first(:conditions => {:user_id => cuser.id})
        headers["Gather"] = "voted"
      else
        headers["Gather"] = "voting"
      end
      render :partial => "voting", :layout => false
    elsif @gather.status == Gather::STATE_PICKING or @gather.status == Gather::STATE_FINISHED
      headers["Gather"] = "picking"
      render :partial => "picking", :layout => false
    end
  end
end
