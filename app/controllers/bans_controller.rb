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
    @ban = Ban.new(params[:ban])
    raise AccessError unless @ban.can_create? cuser

    if @ban.save
      flash[:notice] = t(:bans_create)
      redirect_to(@ban)
    else
      render :new
    end
  end

  def update
    raise AccessError unless @ban.can_update? cuser
    if @ban.update_attributes(params[:ban])
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
end
