# frozen_string_literal: true

module Api
  module V1
    class UsersController < Api::V1::BaseController
      def index
        render json: Api::V1::UsersCollection.as_json
      end

      def show
        @user = User.find_for_api(params[:id], params[:format])

        if @user.nil?
          not_found
          return
        end

        steam = steam_profile(@user) if @user.steamid?
        render json: @user.api_v1_payload(steam_profile: steam)
      rescue ActiveRecord::RecordNotFound
        not_found
      end

      private

      def not_found
        render json: { error: 'User not found' }, status: :not_found
      end

      def steam_profile(user)
        SteamCondenser::Community::SteamId.from_steam_id("STEAM_#{user.steamid}")
      rescue SteamCondenser::Error
        nil
      end
    end
  end
end
