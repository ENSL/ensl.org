class ChallengesController < ApplicationController
  before_filter :get_challenge, only: [:show, :edit, :update, :destroy]

  def index
    @challenges = Challenge.all
  end

  def show
    return_here
  end

  def refresh
    Challenge.past.pending.each do |c|
      c.destroy
    end

    render text: t(:challenges_cleared)
  end

  def new
    @challenge = Challenge.new
    @challenge.user = cuser
    @challenge.contester2 = Contester.active.find params[:id]
    @challenge.get_contester1
    raise AccessError unless @challenge.can_create? cuser
  end

  def create
    @challenge = Challenge.new params[:challenge]
    @challenge.user = cuser
    raise AccessError unless @challenge.can_create? cuser

    if @challenge.valid? and @challenge.save
      flash[:notice] = t(:challenges_create)
      redirect_to @challenge
    else
      render :new
    end
  end

  def update
    @challenge = Challenge.find params[:id]
    raise AccessError unless @challenge.can_update? cuser
    case params[:commit]
    when "Accept"
      @challenge.status = Challenge::STATUS_ACCEPTED
    when "Default time"
      @challenge.status = Challenge::STATUS_DEFAULT
    when "Forfeit"
      @challenge.status = Challenge::STATUS_FORFEIT
    when "Decline"
      @challenge.status = Challenge::STATUS_DECLINED
    end

    if @challenge.update_attributes params[:challenge]
      flash[:notice] = t(:challenges_update)
    end

    render :show
  end

  def destroy
    raise AccessError unless @challenge.can_destroy? cuser
    @challenge.destroy
    return_to
  end

  private

  def get_challenge
    @challenge = Challenge.find params[:id]
  end
end
