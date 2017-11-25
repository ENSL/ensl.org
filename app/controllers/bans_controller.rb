class BansController < ApplicationController
  before_filter :get_ban, only: [:show, :edit, :update, :destroy]

  def index
    @bans = Ban.ordered
  end

  def show
  end

  def new
    @ban = Ban.new
    raise AccessError unless @ban.can_create? cuser
  end

  def edit
    raise AccessError unless @ban.can_update? cuser
  end

  def create
    @ban = Ban.new(ban_create_params)
    raise AccessError unless @ban.can_create? cuser
    @ban.creator = cuser

    if @ban.save
      flash[:notice] = t(:bans_create)
      redirect_to(@ban)
    else
      render :new
    end
  end

  def update
    raise AccessError unless @ban.can_update? cuser
    if @ban.update_attributes(ban_update_params)
      flash[:notice] = t(:bans_update)
      redirect_to(@ban)
    else
      render :edit
    end
  end

  def destroy
    raise AccessError unless @ban.can_destroy? cuser
    @ban.destroy
    redirect_to(bans_url)
  end

  private

  def get_ban
    @ban = Ban.find(params[:id])
  end

  def ban_create_params
    params.require(:ban).pemit(:steamid, :addr, :reason, :len, :user_name, :creator, :ban_type, :ip, :server, :len, :expiry)
  end

  def ban_update_params
    params.require(:ban).permit(:steamid, :addr, :reason, :len, :user_name, :ban_type, :ip, :server, :len, :expiry)
  end
end
