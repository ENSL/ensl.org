module Api
  module V1
    class TeamsController < Api::V1::BaseController
      def index
        render json: Api::V1::TeamsCollection.as_json
      end

      def show
        team = Team.find(params[:id])

        render json: {
          id: team.id,
          name: team.name,
          tag: team.tag,
          logo: team.logo.url,
          roster:
            Teamer
              .joins(:user)
              .select("users.id, users.username, users.team_id, users.steamid, teamers.rank")
              .where(teamers: { team_id: team.id })
              .where("teamers.rank >= ?", Teamer::RANK_MEMBER)
              .map do |user|
              {
                userid: user.id,
                name: user.username,
                steamid: user.steamid,
                rank: user.rank,
                primary: user.team_id == team.id
              }
            end
        }
      rescue ActiveRecord::RecordNotFound
        raise ActionController::RoutingError.new("Team Not Found")
      end
    end
  end
end
