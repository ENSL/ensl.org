class ContestersController < ApplicationController
  before_filter :get_contester, :only => ['show', 'edit', 'update', :recover, :destroy, :recalc]

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
    @contester = Contester.new params[:contester]
    @contester.user = cuser
    raise AccessError unless @contester.can_create? cuser

    if @contester.save
      flash[:notice] = t(:contests_join)
      redirect_to contest_path(@contester.contest_id)
    else
      flash[:error] = t(:errors) + @contester.errors.full_messages.to_s
      redirect_to_back
    end
  end

  def update
    raise AccessError unless @contester.can_update? cuser
    if @contester.update_attributes params[:contester]
      flash[:notice] = t(:contests_contester_update)
      redirect_to @contester
    else
      render :action => "edit"
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
