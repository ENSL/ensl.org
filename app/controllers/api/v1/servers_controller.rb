# frozen_string_literal: true

module Api
  module V1
    class ServersController < Api::V1::BaseController
      def index
        render json: { servers: Server.active_api_v1_payload }
      end
    end
  end
end
