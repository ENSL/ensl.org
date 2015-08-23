class Api::V1::ServersController < Api::V1::BaseController
  def index
    render json: { servers: active_servers }
  end

  private

  def active_servers
    Server.active.map  do |s|
      {
        id: s.id,
        description: s.description,
        dns: s.dns,
        ip: s.ip,
        port: s.port,
        password: s.password,
        category_id: s.category_id
      }
    end
  end
end