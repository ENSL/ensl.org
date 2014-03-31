class MatchesController < ApplicationController
  before_filter :get_match, except: [:index, :new, :create]

  def index
    @matches = Match.active
  end

  def show
    @ownpred = @match.predictions.first conditions: {user_id: cuser.id} if cuser
    @newpred = @match.predictions.build
  end

  def new
    @match = Match.new
    @match.contest = Contest.find params[:id]
    raise AccessError unless @match.can_create? cuser
  end

  def extra
  end

  def score
    raise AccessError unless @match.can_update? cuser, [:matchers_attributes]
    @contester = @match.contester1.team.is_leader?(cuser) ? @match.contester1 : @match.contester2
    @n = 0
  end

  def ref
    raise AccessError unless @match.can_update? cuser, [:report]
    @n = 0
  end

  def edit
    raise AccessError unless @match.can_update? cuser, [:contester1_id]
  end

  def create
    @match = Match.new params[:match]
    raise AccessError unless @match.can_create? cuser

    if @match.save
      flash[:notice] = t(:matches_create)
      redirect_to controller: 'contests', action: 'edit', id: @match.contest
    else
      render :new
    end
  end

  def update
    raise AccessError unless @match.can_update? cuser, params[:match]
    if params[:match][:matchers_attributes]
      params[:match][:matchers_attributes].each do |key, matcher|
        matcher['_destroy'] = matcher['_destroy'] == "keep" ? false : true
        if matcher['user_id'] == ""
          params[:match][:matchers_attributes].delete key
        elsif matcher['user_id'].to_i == 0
          matcher['user_id'] = User.find_by_username(matcher['user_id']).id
        end
      end
    end

    if @match.update_attributes params[:match]
      respond_to do |format|
        format.xml { head :ok }
        format.html do
          flash[:notice] = t(:matches_update)
          #redirect_to_back
          redirect_to @match
        end
      end
    else
      render :edit
    end
  end

  def hltv
    raise AccessError unless @match.can_update? cuser, [:hltv]

    if params[:commit].include? t(:hltv_send)
      @match.hltv_record params[:addr], params[:pwd]
      flash[:notice] = t(:hltv_recording)
    elsif params[:commit].include? t(:hltv_move)
      sleep(90) if params[:wait] == "1"
      @match.hltv_move params[:addr], params[:pwd]
      flash[:notice] = t(:hltv_moved)
    elsif params[:commit].include? t(:hltv_stop)
      sleep(90) if params[:wait] == "1"
      @match.hltv_stop
      flash[:notice] = t(:hltv_stopped)
    end
    redirect_to action: 'show'
  end

  def destroy
    raise AccessError unless @match.can_destroy? cuser
    @match.destroy
    redirect_to controller: 'contests', action: 'edit', id: @match.contest
  end

  private

  def get_match
    @match = Match.find params[:id]
  end
end
