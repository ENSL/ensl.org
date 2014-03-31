class TeamsController < ApplicationController
  before_filter :get_team, only: [:show, :edit, :update, :destroy, :recover]

  def index
    @teams = Team.with_teamers_num(0).ordered
  end

  def show
  end

  def new
    @team = Team.new
    raise AccessError unless @team.can_create? cuser
  end

  def edit
    raise AccessError unless @team.can_update? cuser
  end

  def create
    @team = Team.new params[:team]
    @team.founder = cuser
    raise AccessError unless @team.can_create? cuser

    if @team.save
      flash[:notice] = t(:teams_create)
      redirect_to @team
    else
      render :new
    end
  end

  def update
    raise AccessError unless @team.can_update? cuser
    if @team.update_attributes params[:team]
      if params[:rank]
        @team.teamers.present.each do |member|
          rank = params[:rank]["#{member.id}"]
          if cuser.admin? or (rank.to_i <= cuser.teamers.active.of_team(@team).first.rank)
            if member.rank == Teamer::RANK_JOINER
              member.user.update_attribute :team, @team
            end
            member.update_attribute :rank, rank
            member.update_attribute :comment, params[:comment]["#{member.id}"]
          end
        end
      end
      flash[:notice] = t(:teams_update)
      redirect_to edit_team_path(@team)
    else
      render :edit
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

  def get_team
    @team = Team.find params[:id]
  end
end
