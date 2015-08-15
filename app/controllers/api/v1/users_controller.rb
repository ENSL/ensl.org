class Api::V1::UsersController < Api::V1::BaseController
  def index
    render json: Api::V1::UsersCollection.as_json
  end

  def show
    @user = User.find(params[:id])
    @steam = SteamId.from_steam_id("STEAM_#{@user.steamid}")

    render json: {
      id: @user.id,
      username: @user.username,
      country: @user.country,
      time_zone: @user.time_zone,
      avatar: @user.profile.avatar.url,
      admin: @user.admin?,
      steam: {
        url: @steam.base_url, 
        nickname: @steam.nickname
      },
      bans: {
        gather: @user.banned?(Ban::TYPE_GATHER).present?,
        mute: @user.banned?(Ban::TYPE_MUTE).present?,
        site: @user.banned?(Ban::TYPE_SITE).present?
      },
      team: @user.team.present? ? { id: @user.team.id, name: @user.team.name } : nil
    }
  rescue ActiveRecord::RecordNotFound
    raise ActionController::RoutingError.new('User Not Found')
  end
end
