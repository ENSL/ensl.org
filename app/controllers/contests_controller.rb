class ContestsController < ApplicationController
  before_filter :get_contest, :only => ['show', 'edit', 'update', 'destroy', 'del_map', 'scores', 'recalc']

  def index
    #@contests = Contest.all
    @contests_active = Contest.active
    @contests_inactive = Contest.inactive
  end

  def historical
    case params[:id]
    when "NS1"
      @contests = Contest.with_contesters.ordered.where ["name LIKE ? OR name LIKE ?", "S%:%", "%Night%"]
    else
      @contests = Contest.with_contesters.ordered.where ["id > ?", "113"]
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
    @contest.recalculate
    render :text => t(:score_recalc), :layout => true
  end

  def new
    @contest = Contest.new
    raise AccessError unless @contest.can_create? cuser
  end

  def edit
    raise AccessError unless @contest.can_update? cuser
  end

  def create
    @contest = Contest.new params[:contest]
    raise AccessError unless @contest.can_create? cuser

    if @contest.save
      flash[:notice] = t(:contests_create)
      redirect_to @contest
    else
      render :action => "new"
    end
  end

  def update
    raise AccessError unless @contest.can_update? cuser
    if params[:commit] == "Save"
      if @contest.update_attributes(params[:contest])
        flash[:notice] = t(:contests_update)
        redirect_to @contest
      else
        render :action => "edit"
      end
    elsif params[:commit] == "Add map"
      @contest.maps << Map.find(params[:map])
      render :action => "edit"
    elsif params[:commit] == "Add team"
      contester = Contester.new
      contester.team = Team.find params[:team]
      contester.contest = @contest
      contester.active = true
      if contester.valid?
        contester.save(false)
      else
        @contest.errors.add_to_base contester.errors.full_messages.to_s
      end
      render :action => "edit"
    end
  end

  def del_map
    raise AccessError unless @contest.can_update? cuser
    @contest.maps.delete(Map.find(params[:id2]))
    render :action => "edit"
  end

  def destroy
    raise AccessError unless @contest.can_destroy? cuser
    @contest.destroy
    redirect_to contests_url
  end

  private

  def get_contest
    @contest = Contest.find params[:id]
  end
end
