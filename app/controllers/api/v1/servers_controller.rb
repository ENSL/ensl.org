# frozen_string_literal: true

module Api
  module V1
    class ServersController < Api::V1::BaseController
      def index
        render json: { servers: active_servers }
      end

      private

      def active_servers
        Server.active.map do |s|
          {
            id: s.id,
            name: s.name,
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
  end
end
