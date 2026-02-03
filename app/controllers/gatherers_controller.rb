class GatherersController < ApplicationController
  before_action :get_gatherer, except: [:create]

  def create
    result = Gathers::Join.call(actor: cuser, params: Gatherer.params(params, cuser))
    @gatherer = result.gatherer

    if result.success?
      flash[:notice] = t(:gathers_join)
    else
      flash[:error] = @gatherer&.errors&.full_messages&.to_sentence || result.error.to_s
    end

    respond_to do |format|
      format.turbo_stream do
        @gather = result.gather || @gatherer&.gather
        @gatherer = result.gatherer || @gather&.gatherers&.of_user(cuser)&.first
        if result.success?
          flash.now[:notice] = flash[:notice]
        else
          flash.now[:error] = flash[:error]
        end
        render turbo_stream: [
          turbo_stream.replace('notification', partial: 'application/messages'),
          turbo_stream.replace(view_context.dom_id(@gather, :frame), partial: 'gathers/frame',
                                                                     locals: { gather: @gather, gatherer: @gatherer })
        ]
      end
      format.html { redirect_to(result.gather || @gatherer&.gather || '/') }
    end
  end

  def update
    @gatherer = Gatherer.find params[:gatherer][:id]
    raise AccessError unless @gatherer.can_update?(cuser, Gatherer.params(params, cuser))

    if @gatherer.update(Gatherer.params(params, cuser))
      flash[:notice] = t(:gatherers_update)
      Gathers::Broadcaster.call(@gatherer.gather)
    else
      flash[:error] = @gatherer.errors.full_messages.to_sentence
    end

    redirect_to_back
  end

  def status
    raise AccessError unless @gatherer.can_destroy? cuser

    states = {
      'leaving' => Gatherer::STATE_LEAVING,
      'away' => Gatherer::STATE_AWAY,
      'active' => Gatherer::STATE_ACTIVE
    }

    if states.has_key?(params[:status])
      @gatherer.update_attribute(:status, states[params[:status]])
      Gathers::Broadcaster.call(@gatherer.gather)
    end

    render body: nil, status: 200
  end

  def destroy
    service = if cuser && (cuser.admin? || cuser.gather_moderator?) && @gatherer.user != cuser
                Gathers::Kick
              else
                Gathers::Leave
              end

    result = service.call(actor: cuser, gatherer: @gatherer)
    if result.success?
      flash[:notice] = t(:gatherers_update)
    else
      flash[:error] = result.error.to_s
    end

    redirect_to(result.gather || @gatherer.gather)
  end

  private

  def get_gatherer
    @gatherer = Gatherer.find params[:id]
  end
end
