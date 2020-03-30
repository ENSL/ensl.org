class ContestsController < ApplicationController
  before_action :get_contest, only: [:show, :edit, :update, :destroy, :del_map, :scores, :recalc, :confirmed_matches]

  def index
    # @contests = Contest.all
    @contests_active = Contest.active
    @contests_inactive = Contest.inactive
  end

  def historical
    case params[:id]
    when "NS1"
      @contests = Contest.all.ordered.includes(:contesters).where("name LIKE ? OR name LIKE ?", "S%:%", "%Night%")
    else
      @contests = Contest.all.ordered.includes(:contesters).where("id > ?", "113")
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
    @friendly = params[:friendly] ? @contest.contesters.find(params[:friendly]) : @contest.contesters.first
    @rounds = [@contest.modulus_even, @contest.modulus_3to1, @contest.modulus_4to0]
    @rounds.each_index do |key|
      if params["rounds"] and params["rounds"]["#{key}"]
        @rounds[key] = params["rounds"]["#{key}"].to_f
      end
    end
    @weight = params[:weight] ? params[:weight].to_f : @contest.weight
  end

  def recalc
    raise AccessError unless @contest.can_update? cuser
    @contest.recalculate
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
      render :new
    end
  end

  def update
    raise AccessError unless @contest.can_update? cuser
    if update_type == "contest"
      if @contest.update_attributes(Contest.params(params, cuser))
        flash[:notice] = t(:contests_update)
        redirect_to @contest
      else
        render :edit
      end
    elsif update_type == "map"
      @contest.maps << Map.find(params[:map])
      render :edit
    elsif update_type == "team"
      contester = Contester.new
      contester.team = Team.find params[:team]
      contester.contest = @contest
      contester.active = true
      if contester.valid?
        contester.save(false)
      else
        @contest.errors.add_to_base contester.errors.full_messages.to_s
      end
      render :edit
    end
  end

  def del_map
    raise AccessError unless @contest.can_update? cuser
    @contest.maps.delete(Map.find(params[:id2]))
    render :edit
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

  def get_contest
    @contest = Contest.find params[:id]
  end

  def update_type
    params[:type]
  end
end
