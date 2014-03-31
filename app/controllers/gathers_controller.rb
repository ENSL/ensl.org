class GathersController < ApplicationController
  before_filter :get_gather, except: [:latest, :index, :create]
  respond_to :html, :js

  def index
    @gathers = Gather.ordered.limit(50).all
  end

  def show
  end

  def latest
    @gather = Gather.last(params[:game])
    redirect_to @gather
  end

  def edit
    @gather.admin = true
  end

  def create
    @gather = Gather.new
    @gather.category_id = params[:gather][:category_id]
    raise AccessError unless @gather.can_create? cuser

    if @gather.save
      flash[:notice] = t(:gather_create)
    end

    redirect_to_back
  end

  def update
    @gather = Gather.basic.find(params[:id])
    raise AccessError unless @gather.can_update? cuser

    Gatherer.transaction do
      Gather.transaction do
        if @gather.update_attributes params[:gather]
          flash[:notice] = 'Gather was successfully updated.'
        end
      end
    end

    redirect_to @gather
  end

  def pick
    @gatherer = @gather.gatherers.find(params[:player])
    raise AccessError unless @gatherer.can_update? cuser, params

    Gatherer.transaction do
      Gather.transaction do
        if @gatherer.update_attribute :team, @gatherer.gather.turn
          flash[:notice] = t(:gathers_user_pick)
        else
          flash[:error] = @gatherer.errors.full_messages.to_s
        end
      end
    end

    redirect_to @gather
  end

  private

  def get_gather
    Gather.transaction do
      @gather = Gather.basic.find(params[:id], :lock => true)
      @gather.refresh cuser
    end

    @gatherer = @gather.gatherers.of_user(cuser).first if cuser
  end
end
