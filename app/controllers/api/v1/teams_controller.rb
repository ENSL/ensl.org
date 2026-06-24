# frozen_string_literal: true

module Api
  module V1
    class TeamsController < Api::V1::BaseController
      def index
        render json: Api::V1::UsersCollection.as_json
      end

      def show
        @team = Team.find params[:id]
        render json: @team.api_v1_payload
      rescue ActiveRecord::RecordNotFound
        raise ActionController::RoutingError, 'User Not Found'
      end
    end
  end
end
