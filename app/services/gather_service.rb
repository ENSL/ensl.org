# app/services/gather_service.rb
class GatherService
  def self.call(gather)
    Gathers::Broadcaster.call(gather)
  end
end
