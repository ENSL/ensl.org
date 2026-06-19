# frozen_string_literal: true

class ChallengesController < ApplicationController
  before_action :get_challenge, only: %i[show edit update destroy]

  def index
    @challenges = Challenge.all
  end

  def show
    return_here
  end

  def new
    @challenge = Challenge.new
    @challenge.user = cuser
    @challenge.contester2 = Contester.active.find params[:id]
    contest = @challenge.contester2.contest
    @challenge.contester1 = @challenge.user.active_contesters.of_contest(contest).first
    @challenge.match_time = Time.current + 2.days
    raise AccessError unless @challenge.can_create? cuser
  end

  def create
    @challenge = Challenge.new(Challenge.params(params, cuser))
    @challenge.user = cuser
    raise AccessError unless @challenge.can_create? cuser

    if @challenge.valid? && @challenge.save
      flash[:notice] = t(:challenges_create)
      redirect_to @challenge
    else
      render :new
    end
  end

  def update
    raise AccessError unless @challenge.can_update? cuser

    case params[:commit]
    when 'Accept'
      @challenge.status = Challenge::STATUS_ACCEPTED
    when 'Default time'
      @challenge.status = Challenge::STATUS_DEFAULT
    when 'Forfeit'
      @challenge.status = Challenge::STATUS_FORFEIT
    when 'Decline'
      @challenge.status = Challenge::STATUS_DECLINED
    end

    flash[:notice] = t(:challenges_update) if @challenge.update(Challenge.params(params, cuser))

    @challenge.reload if @challenge.persisted?
    render :show
  end

  def destroy
    raise AccessError unless @challenge.can_destroy? cuser

    @challenge.destroy
    # return_to FIX ME from challenge side
    render plain: t(:challenges_cleared)
  end

  # Custom method

  def refresh
    Challenge.past.pending.each(&:destroy)

    render plain: t(:challenges_cleared)
  end

  private

  def get_challenge
    @challenge = Challenge.find params[:id]
  end
end
