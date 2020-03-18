class ContestersController < ApplicationController
  before_action :get_contester, only: [:show, :edit, :update, :recover, :destroy, :recalc]

  def show
    @matches = Match.future.unfinished.ordered.of_contester @contester
    @results = Match.finished.ordered.of_contester @contester

    raise AccessError unless @contester and @contester.contest and @contester.team

    if @contester.contest.status == Contest::STATUS_CLOSED
      @members = @contester.team.teamers.distinct.ordered
    else
      @members = @contester.team.teamers.active.distinct.ordered
    end
  end

  def edit
    raise AccessError unless @contester.can_update? cuser
  end

  def create
    @contester = Contester.new(Contester.params(params, cuser))
    @contester.user = cuser
    raise AccessError unless @contester.can_create? cuser
    if @contester.contest.contest_type == Contest::TYPE_LADDER
      @contester.score = @contester.contest.contesters.active.count + 1
    end

    if @contester.save
      flash[:notice] = t(:contests_join)
      redirect_to contest_path(@contester.contest_id)
    else
      flash[:error] = @contester.errors.full_messages[0]
      redirect_to_back
    end
  end

  def update
    raise AccessError unless @contester.can_update? cuser

    if @contester.contest.contest_type == Contest::TYPE_LADDER
      old_rank = @contester.score
      new_rank = params[:contester][:score].to_i
      raise Error, t(:rank_invalid) unless new_rank > 0 and
        new_rank <= @contester.contest.contesters.active.count
      if old_rank != new_rank
        @contester.contest.update_ranks(@contester, old_rank, new_rank)
      end
    end

    if @contester.update_attributes(Contester.params(params, cuser))
      flash[:notice] = t(:contests_contester_update)
      redirect_to @contester.contest
    else
      render :edit
    end
  end

  def recover
    raise AccessError unless @contester.can_destroy? cuser
    @contester.recover
    redirect_to_back
  end

  def destroy
    raise AccessError unless @contester.can_destroy? cuser
    @contester.destroy
    redirect_to_back
  end

  private

  def get_contester
    @contester = Contester.find params[:id]
  end
end
