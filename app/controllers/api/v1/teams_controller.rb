class Api::V1::TeamsController < Api::V1::BaseController
  def index
    render json: Api::V1::UsersCollection.as_json
  end

  def show
    @team = Team.find params[:id]
    render json: {
      id: @team.id,
      name: @team.name,
      logo: @team.logo,
      members: @team.teamers.active.map do |m| 
        { 
          id: m.user.id,
          username: m.user.username,
          steamid: m.user.steamid
        } 
      end
    }
  rescue ActiveRecord::RecordNotFound
    raise ActionController::RoutingError.new("User Not Found")
  end
end
