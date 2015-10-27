class Api::V1::UsersController < Api::V1::BaseController
  def index
    render json: Api::V1::UsersCollection.as_json
  end

  def show
    @user = User.find(params[:id])
    if @user.steamid.present?
      @steam = steam_profile @user
    end

    render json: {
      id: @user.id,
      username: @user.username,
      country: @user.country,
      time_zone: @user.time_zone,
      avatar: @user.profile.avatar.url,
      admin: @user.admin?,
      moderator: @user.gather_moderator?,
      steam: @user.steamid.nil? ? nil : {
        id: @user.steamid,
        url: @steam.nil? ? nil : @steam.base_url,
        nickname: @steam.nil? ? nil : @steam.nickname
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

  private

  def steam_profile(user)
    SteamCondenser::Community::SteamId.from_steam_id("STEAM_#{user.steamid}")
  rescue SteamCondenser::Error
    nil
  end
end
