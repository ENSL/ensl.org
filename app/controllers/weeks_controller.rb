class WeeksController < ApplicationController
  before_action :get_week, except: %i[new create]

  def new
    @week = Week.new
    @week.contest = Contest.find(params[:id])
    raise AccessError unless @week.can_create? cuser
  end

  def edit
    raise AccessError unless @week.can_update? cuser
  end

  def create
    @week = Week.new(Week.params(params, cuser))
    raise AccessError unless @week.can_create? cuser

    if @week.save
      flash[:notice] = t(:weeks_create)
      redirect_to @week.contest
    else
      flash.now[:error] = @week.errors.full_messages.to_sentence.presence || t(:error)
      render :new, status: :unprocessable_entity
    end
  end

  def update
    raise AccessError unless @week.can_update? cuser

    if @week.update(Week.params(params, cuser))
      flash[:notice] = t(:weeks_update)
      redirect_to @week.contest
    else
      flash.now[:error] = @week.errors.full_messages.to_sentence.presence || t(:error)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    raise AccessError unless @week.can_destroy? cuser

    @week.destroy
    flash[:notice] = t(:weeks_destroy)
    redirect_to edit_contest_path(@week.contest, anchor: 'weeks')
  end

  private

  def get_week
    @week = Week.find(params[:id])
  end
end
