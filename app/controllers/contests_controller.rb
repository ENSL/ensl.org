# frozen_string_literal: true

class ContestsController < ApplicationController
  before_action :load_contest, only: %i[show edit update destroy del_map scores recalc confirmed_matches]

  def index
    # @contests = Contest.all
    @contests_active = Contest.active
    @contests_inactive = Contest.inactive
  end

  def historical
    @contests = case params[:id]
                when 'NS1'
                  Contest.all.ordered.includes(:contesters).where('name LIKE ? OR name LIKE ?', 'S%:%', '%Night%')
                else
                  Contest.all.ordered.includes(:contesters).where('id > ?', '113')
                end
  end

  def current
    @contests = Contest.active
  end

  def show
    # TODO
    # @friendly = cuser.active_contesters.of_contest(@contest).active.first if cuser
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
      render :new, status: :unprocessable_entity
    end
  end

  # FIXME: don't use this kind of update
  def update
    raise AccessError unless @contest.can_update? cuser

    case update_type
    when 'contest'
      if @contest.update(Contest.params(params, cuser))
        flash[:notice] = t(:contests_update)
        redirect_to @contest
      else
        render :edit, status: :unprocessable_entity
      end
    when 'map'
      map = Map.find_by(id: params[:map])
      if map.nil?
        flash.now[:error] = t(:error)
        render :edit, status: :unprocessable_entity
      else
        @contest.maps << map unless @contest.maps.include?(map)
        flash[:notice] = t(:maps_update)
        redirect_to edit_contest_path(@contest, contest: 'maps')
      end
    when 'team'
      contester = Contester.new(team: Team.find(params[:team]), contest: @contest, active: true)
      if contester.valid?
        contester.save!
      else
        @contest.errors.add(:base, contester.errors.full_messages.to_sentence)
      end
      render :edit
    end
  end

  def del_map
    raise AccessError unless @contest.can_update? cuser

    map = Map.find_by(id: params[:id2])
    if map
      @contest.maps.delete(map)
      flash[:notice] = t(:maps_destroy)
    else
      flash[:error] = t(:error)
    end
    redirect_to edit_contest_path(@contest, contest: 'maps')
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

  def update_type
    params[:type]
  end
end
