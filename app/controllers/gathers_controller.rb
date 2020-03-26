class GathersController < ApplicationController
  before_action :get_gather, except: [:latest, :index, :create]
  respond_to :html, :js

  def index
    @gathers = Gather.ordered.limit(50).all.paginate(per_page: 40, page: params[:page])
  end

  def show
    render layout: 'full'
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
        if @gather.update_attributes(Gather.params(params, cuser))
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
      @gather = Gather.basic.where(id: params[:id]).lock(true).first
      @gather.refresh cuser
    end

    @gatherer = @gather.gatherers.of_user(cuser).first if cuser
    update_gatherers
  end

  def update_gatherers
    # Update user that has left and came back
    if @gatherer and @gatherer.status == Gatherer::STATE_LEAVING
      @gatherer.update_attribute(:status, Gatherer::STATE_ACTIVE)
    end

    # Remove any users that left over 30 seconds ago
    removed_users = false
    @gather.gatherers.each do |gatherer|
      if gatherer.status == Gatherer::STATE_LEAVING and gatherer.updated_at < Time.now - 30
        removed_users = true
        gatherer.destroy
      end
    end

    @gather.reload if removed_users
  end
end
