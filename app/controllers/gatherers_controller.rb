class GatherersController < ApplicationController
  before_filter :get_gatherer, except: [:create]

  def create
    Gather.transaction do
      Gatherer.transaction do
        @gatherer = Gatherer.new params[:gatherer]
        @gatherer.gather.lock!
        raise AccessError unless @gatherer.can_create? cuser, params[:gatherer]

        if @gatherer.save
          flash[:notice] = t(:gathers_join)
        else
          flash[:error] = @gatherer.errors.full_messages.to_s
        end
      end
    end

    redirect_to @gatherer.gather
  end

  def update
    @gatherer = Gatherer.find params[:gatherer][:id]
    raise AccessError unless @gatherer.can_update? cuser, params[:gatherer]

    if @gatherer.update_attributes params[:gatherer]
      flash[:notice] = t(:gatherers_update)
    else
      flash[:error] = @gatherer.errors.full_messages.to_s
    end

    redirect_to_back
  end

  def destroy
    raise AccessError unless @gatherer.can_destroy? cuser

    @gatherer.destroy
    redirect_to @gatherer.gather
  end

  private

  def get_gatherer
    @gatherer = Gatherer.find params[:id]
  end
end
