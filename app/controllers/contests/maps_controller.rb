# frozen_string_literal: true

module Contests
  class MapsController < ApplicationController
    before_action :load_contest

    def create
      raise AccessError unless @contest.can_update? cuser

      if @contest.add_map_by_id(params[:map])
        flash[:notice] = t('contests.maps.added')
      else
        flash[:error] = t(:error)
      end

      redirect_to edit_contest_path(@contest, contest: 'maps')
    end

    def destroy
      raise AccessError unless @contest.can_update? cuser

      if @contest.remove_map_by_id(params[:id])
        flash[:notice] = t('contests.maps.removed')
      else
        flash[:error] = t(:error)
      end

      redirect_to edit_contest_path(@contest, contest: 'maps')
    end

    private

    def load_contest
      @contest = Contest.find(params[:contest_id])
    end
  end
end
