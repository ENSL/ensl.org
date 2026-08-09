# frozen_string_literal: true

class GatherersController < ApplicationController
  before_action :load_gatherer, except: %i[create pick]

  def create
    join_result = Gathers::Join.call(actor: cuser, params: Gatherer.params(params, cuser))
    @gatherer = join_result.gatherer
    apply_join_flash(join_result)
    respond_to_join(join_result)
  end

  def update
    @gatherer = Gatherer.find(params[:gatherer][:id])
    update_result = @gatherer.update_for_actor(params, cuser)
    raise AccessError unless update_result.authorized

    apply_gatherer_update_flash(update_result)
    redirect_to_back
  end

  def status
    raise AccessError unless @gatherer.can_destroy? cuser

    @gatherer.update_status_from_key(params[:status])
    render body: nil, status: :ok
  end

  def pick
    player = Gatherer.find(params[:player])
    @gather = player.gather
    result = Gathers::CaptainPick.call(actor: cuser, gather: @gather, player_id: player.id)
    apply_pick_flash(result)
    respond_to_pick(result)
  end

  def destroy
    result = gather_destroy_service.call(actor: cuser, gatherer: @gatherer)
    apply_gatherer_destroy_flash(result)
    redirect_to(result.gather || @gatherer.gather)
  end

  private

  def load_gatherer = @gatherer = Gatherer.find(params[:id])

  def respond_to_join(join_result)
    respond_to do |format|
      format.turbo_stream { render_join_turbo_stream(join_result) }
      format.html { redirect_to(join_result.gather || @gatherer&.gather || '/') }
    end
  end

  def respond_to_pick(result)
    respond_to do |format|
      format.turbo_stream { render_pick_turbo_stream(result) }
      format.html { redirect_to(result.gather || @gather) }
    end
  end

  def apply_join_flash(join_result)
    if join_result.success?
      flash[:notice] = t('gathers.join')
    else
      flash[:error] = @gatherer&.errors&.full_messages&.to_sentence || join_result.error.to_s
    end
  end

  def apply_pick_flash(result)
    if result.success?
      flash[:notice] = t('gathers.user_pick')
    else
      flash[:error] = result.error.to_s
    end
  end

  def apply_gatherer_update_flash(update_result)
    if update_result.updated
      flash[:notice] = t('gatherers.update')
    else
      flash[:error] = update_result.errors.full_messages.to_sentence
    end
  end

  def gather_destroy_service
    return Gathers::Kick if cuser && (cuser.admin? || cuser.gather_moderator?) && @gatherer.user != cuser

    Gathers::Leave
  end

  def apply_gatherer_destroy_flash(result)
    if result.success?
      flash[:notice] = t('gatherers.update')
    else
      flash[:error] = result.error.to_s
    end
  end

  def render_pick_turbo_stream(result)
    @gather = result.gather || @gather
    @gatherer = @gather.gatherers.of_user(cuser).first if cuser
    sync_flash_now(result.success?)
    render_gather_turbo_stream
  end

  def render_join_turbo_stream(join_result)
    @gather = join_result.gather || @gatherer&.gather
    @gatherer = join_result.gatherer || @gather&.gatherers&.of_user(cuser)&.first
    sync_flash_now(join_result.success?)
    render_gather_turbo_stream
  end

  def sync_flash_now(success) = flash.now[success ? :notice : :error] = flash[success ? :notice : :error]

  def render_gather_turbo_stream
    render turbo_stream: [
      turbo_stream.replace('notification', partial: 'application/messages'),
      turbo_stream.replace(view_context.dom_id(@gather, :frame), partial: 'gathers/frame',
                                                                 locals: { gather: @gather, gatherer: @gatherer })
    ]
  end
end
