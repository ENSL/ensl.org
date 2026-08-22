# frozen_string_literal: true

class TeamersController < ApplicationController
  def index
    head :not_acceptable
  end

  def create
    @teamer, teamer_params = Teamer.build_for_actor(params, cuser)
    raise AccessError unless @teamer.can_create?(cuser, teamer_params)

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

  def submit_teamer_application
    if @teamer.submit_for_actor(cuser)
      flash[:notice] = t(:applying_team) + @teamer.team.to_s
    else
      flash[:error] = @teamer.errors.full_messages.to_s
    end
  end
end
