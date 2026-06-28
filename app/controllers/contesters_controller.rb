# frozen_string_literal: true

class ContestersController < ApplicationController
  before_action :load_contester, only: %i[show edit update recover destroy recalc]

  def show
    @matches = Match.future.unfinished.ordered.of_contester @contester
    @results = Match.finished.ordered.of_contester @contester

    raise AccessError unless @contester&.contest && @contester.team

    @members = @contester.lineup_for_show
  end

  def edit
    raise AccessError unless @contester.can_update? cuser
  end

  def create
    @contester, contester_params = Contester.build_for_create(raw_params: params, actor: cuser)
    raise AccessError unless @contester.can_create?(cuser, contester_params)

    save_and_respond(@contester, notice: :contests_join, location: teams_tab_location, template: :new) do
      @contester.save
    end
  end

  def update
    raise AccessError unless @contester.can_update? cuser

    @contester.rebalance_ladder_rank!(params.dig(:contester, :score))
    save_and_respond(@contester, notice: :contests_contester_update, location: teams_tab_location, template: :edit) do
      @contester.update(Contester.params(params, cuser))
    end
  end

  def recover
    raise AccessError unless @contester.can_destroy? cuser

    @contester.recover
    flash[:notice] = t(:contests_contester_recovered)
    redirect_to_teams_tab
  end

  def destroy
    raise AccessError unless @contester.can_destroy? cuser

    @contester.destroy
    flash[:notice] = t(:contests_contester_destroy)
    redirect_to_teams_tab
  end

  private

  def load_contester
    @contester = Contester.find params[:id]
  end

  def redirect_to_teams_tab
    redirect_to teams_tab_location
  end

  def teams_tab_location
    edit_contest_path(@contester.contest_id, anchor: 'teams')
  end
end
