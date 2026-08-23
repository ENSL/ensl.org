# frozen_string_literal: true

class TeamersController < ApplicationController
  def index
    head :not_acceptable
  end

  def create
    @teamer, teamer_params = Teamer.build_for_actor(params, cuser)
    raise AccessError unless @teamer.can_create?(cuser, teamer_params)

    return add_team_member if teamer_params[:username].present?

    submit_teamer_application

    respond_to do |format|
      format.html { redirect_to_back }
      format.turbo_stream { redirect_to @teamer.team }
    end
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

  private

  def add_team_member
    @teamer.rank = Teamer::RANK_MEMBER
    if @teamer.submit_for_actor(cuser)
      flash[:notice] = t(:teams_member_add)
      redirect_to edit_team_url(@teamer.team, anchor: 'members')
    else
      @team = @teamer.team
      @new_teamer = @teamer
      respond_with_validation_errors(@teamer, template: 'teams/edit')
    end
  end

  def submit_teamer_application
    if @teamer.submit_for_actor(cuser)
      flash[:notice] = t(:applying_team) + @teamer.team.to_s
    else
      flash[:error] = @teamer.errors.full_messages.to_s
    end
  end
end
