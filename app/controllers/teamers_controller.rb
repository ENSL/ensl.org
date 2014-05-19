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

  def edit
    logger.info params
    logger.info "hello world"
    teamer_id = params["teamer"]
    @teamer = Teamer.find(teamer_id)
    @teamer.team_id = params["id"]
    @teamer.save
    redirect_to_back
  end

  def destroy
    @teamer = Teamer.find params[:id]
    raise AccessError unless @teamer.can_destroy? cuser

    @teamer.destroy
    redirect_to_back
  end
end
