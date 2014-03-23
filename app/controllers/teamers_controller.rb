class TeamersController < ApplicationController
  def create
    @teamer = Teamer.new params[:teamer]
    raise AccessError unless @teamer.can_create? cuser, params[:teamer]
    @teamer.user = cuser unless cuser.admin?

    if @teamer.save
      flash[:notice] = t(:applying_team) + @teamer.team.to_s
    else
      flash[:error] = @teamer.errors.full_messages.to_s
    end

    redirect_to_back
  end

  def destroy
    @teamer = Teamer.find params[:id]
    raise AccessError unless @teamer.can_destroy? cuser

    @teamer.destroy
    redirect_to_back
  end
end
