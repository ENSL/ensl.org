# frozen_string_literal: true

class TeamsController < ApplicationController
  before_action :load_team, only: %i[show edit update destroy recover]

  def index
    @teams = Team.search(params[:search]).paginate(per_page: 80, page: params[:page]).ordered
  end

  def show
    @teamer = Teamer.new
    @teamer.user = @user
  end

  def new
    @team = Team.new
    raise AccessError unless @team.can_create? cuser
  end

  def edit
    raise AccessError unless @team.can_update? cuser
  end

  def create
    @team = Team.new(Team.params(params, cuser))
    @team.founder = cuser
    raise AccessError unless @team.can_create? cuser

    if @team.save
      flash[:notice] = flash_action_message(:create, @team)
      redirect_to @team
    else
      respond_with_validation_errors(@team, template: :new)
    end
  end

  def update
    raise AccessError unless @team.can_update? cuser

    if @team.update(Team.params(params, cuser))
      @team.apply_member_rank_updates!(actor: cuser, rank_params: params[:rank], comment_params: params[:comment])
      flash[:notice] = flash_action_message(:update, @team)
      redirect_to edit_team_path(@team)
    else
      respond_with_validation_errors(@team, template: :edit)
    end
  end

  def destroy
    raise AccessError unless @team.can_destroy? cuser

    @team.destroy
    redirect_to(teams_url)
  end

  def recover
    raise AccessError unless @team.can_destroy? cuser

    @team.recover
    redirect_to(teams_url)
  end

  private

  def load_team
    @team = Team.find params[:id]
  end
end
