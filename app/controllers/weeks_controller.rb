# frozen_string_literal: true

class WeeksController < ApplicationController
  before_action :load_week, except: %i[new create]

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

    save_and_respond(@week, notice: [:create, @week],
                            location: edit_contest_path(@week.contest, contest: 'weeks'),
                            template: :new) { @week.save }
  end

  def update
    raise AccessError unless @week.can_update? cuser

    save_and_respond(@week, notice: [:update, @week],
                            location: edit_contest_path(@week.contest, contest: 'weeks'),
                            template: :edit) { @week.update(Week.params(params, cuser)) }
  end

  def destroy
    raise AccessError unless @week.can_destroy? cuser

    @week.destroy
    flash[:notice] = flash_action_message(:destroy, @week)
    redirect_to edit_contest_path(@week.contest, contest: 'weeks')
  end

  private

  def load_week
    @week = Week.find(params[:id])
  end
end
