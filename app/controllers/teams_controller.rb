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

  def replace_teamer
    redirect_to_back
  end

  def edit
    raise AccessError unless @team.can_update? cuser
  end

  def create
    @team = Team.new(Team.params(params, cuser))
    @team.founder = cuser
    raise AccessError unless @team.can_create? cuser

    if @team.save
      flash[:notice] = t(:teams_create)
      redirect_to @team
    else
      respond_with_validation_errors(@team, template: :new)
    end
  end

  def update
    raise AccessError unless @team.can_update? cuser

    if @team.update(Team.params(params, cuser))
      # FIXME: move this logic to model
      if params[:rank]
        @team.teamers.each do |member|
          # Contains new rank as given by submitted parameters
          new_rank = params[:rank][member.id.to_s]
          next if new_rank.nil?
          # Can only set own rank to equal or lower than current rank
          next unless cuser.admin? || (new_rank.to_i <= cuser.teamers.active.of_team(@team).first.rank)
          # Don't allow setting members back to rank joining
          next if new_rank.to_i == Teamer::RANK_JOINER && member.rank != Teamer::RANK_JOINER

          # Update team when rank changes from joiner to member or higher
          if member.rank == Teamer::RANK_JOINER && new_rank.to_i >= Teamer::RANK_MEMBER
            member.user.update_attribute :team, @team
          end
          member.update_attribute :rank, new_rank
          member.update_attribute :comment, params[:comment][member.id.to_s]
        end
      end
      flash[:notice] = t(:teams_update)
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
