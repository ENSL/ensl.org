# frozen_string_literal: true

class ContestsController < ApplicationController
  before_action :load_contest, only: %i[show edit update destroy scores recalc confirmed_matches]

  def index
    # @contests = Contest.all
    @contests_active = Contest.active
    @contests_inactive = Contest.inactive
  end

  def historical
    @contests = Contest.historical(params[:id])
  end

  def current
    @contests = Contest.active
  end

  def show
    @friendly = cuser&.active_contesters&.of_contest(@contest)&.first
  end

  def scores
    raise AccessError unless @contest.contest_type == Contest::TYPE_LADDER

    state = @contest.scores_page_state(
      friendly_id: params[:friendly],
      rounds_param: params[:rounds],
      weight_param: params[:weight]
    )
    @friendly = state[:friendly]
    @rounds = state[:rounds]
    @modulus_base = state[:modulus_base]
    @weight = state[:weight]
  end

  def recalc
    raise AccessError unless @contest.can_update? cuser

    @contest.recalculate
    flash[:notice] = 'Contest points recalculated.'
    redirect_to_back
  end

  def new
    @contest = Contest.new
    raise AccessError unless @contest.can_create? cuser
  end

  def edit
    raise AccessError unless @contest.can_update? cuser
  end

  def create
    @contest = Contest.new(Contest.params(params, cuser))
    raise AccessError unless @contest.can_create? cuser

    if @contest.save
      flash[:notice] = t(:contests_create)
      redirect_to @contest
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    raise AccessError unless @contest.can_update? cuser

    if @contest.update(Contest.params(params, cuser))
      flash[:notice] = t(:contests_update)
      redirect_to @contest
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    raise AccessError unless @contest.can_destroy? cuser

    @contest.destroy
    redirect_to contests_url
  end

  def confirmed_matches
    @match_props = MatchProposal.confirmed_for_contest(@contest)
  end

  private

  def load_contest
    @contest = Contest.find params[:id]
  end
end
