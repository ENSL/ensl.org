class TeamersController < ApplicationController
  def index
  end

  def create
    @old_application = cuser.teamers.joining.count == 0 ? nil : cuser.teamers.joining.first
    @teamer = Teamer.new(Teamer.params(params, cuser))
    raise AccessError unless @teamer.can_create?(cuser, Teamer.params(params, cuser))

    @teamer.user = cuser unless cuser.admin?

    if @teamer.save
      flash[:notice] = t(:applying_team) + @teamer.team.to_s
      @old_application && @old_application.destroy
    else
      flash[:error] = @teamer.errors.full_messages.to_s
    end

    respond_to do |format|
      format.html { redirect_to_back }
      format.turbo_stream { redirect_to @teamer.team }
    end
  end

  def edit
    teamer_id = params['teamer']
    @teamer = Teamer.find(teamer_id)
    @teamer.team_id = params['id']
    @teamer.save
    redirect_to_back
  end

  def destroy
    @teamer = Teamer.find params[:id]
    raise AccessError unless @teamer.can_destroy? cuser

    @teamer.destroy
    respond_to do |format|
      format.html { redirect_to_back }
      format.turbo_stream { head :no_content }
    end
  end
end
