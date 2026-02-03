# app/services/broadcast_gather.rb
class BroadcastGather
  def self.call(gather)
    Gathers::Broadcaster.call(gather)
  end
end
