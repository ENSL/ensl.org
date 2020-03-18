class GatherersController < ApplicationController
  before_action :get_gatherer, except: [:create]

  def create
    Gather.transaction do
      Gatherer.transaction do
        @gatherer = Gatherer.new(Gatherer.params(params, cuser))
        @gatherer.gather.lock!
        raise AccessError unless @gatherer.can_create?(cuser, Gatherer.params(params, cuser))

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
    raise AccessError unless @gatherer.can_update?(cuser, Gatherer.params(params, cuser))

    if @gatherer.update_attributes(Gatherer.params(params, cuser))
      flash[:notice] = t(:gatherers_update)
    else
      flash[:error] = @gatherer.errors.full_messages.to_s
    end

    redirect_to_back
  end

  def status
    raise AccessError unless @gatherer.can_destroy? cuser

    states = {
      "leaving" => Gatherer::STATE_LEAVING,
      "away" => Gatherer::STATE_AWAY,
      "active" => Gatherer::STATE_ACTIVE,
    }

    if states.has_key?(params[:status])
      @gatherer.update_attribute(:status, states[params[:status]])
    end

    render :nothing => true, :status => 200
  end

  def destroy
    raise AccessError unless @gatherer.can_destroy? cuser

    @gather = @gatherer.gather
    @gatherer.destroy
    redirect_to @gather
  end

  private

  def get_gatherer
    @gatherer = Gatherer.find params[:id]
  end
end
