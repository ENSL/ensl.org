# frozen_string_literal: true

class GathersController < ApplicationController
  before_action :load_gather, except: %i[latest index create version]

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
    @gather = Gather.new(category_id: params.dig(:gather, :category_id))
    raise AccessError unless @gather.can_create? cuser

    flash[:notice] = t(:gather_create) if @gather.save

    redirect_to_back
  end

  def update
    @gather = Gather.basic.find(params[:id])
    raise AccessError unless @gather.can_update? cuser

    @gather.admin = true

    Gatherer.transaction do
      Gather.transaction do
        if @gather.update(Gather.params(params, cuser))
          Gathers::Broadcaster.call(@gather)
          flash[:notice] = 'Gather was successfully updated.'
        end
      end
    end

    redirect_to @gather
  end

  # FIXME: Use gatherers.update
  def pick
    result = Gathers::CaptainPick.call(actor: cuser, gather: @gather, player_id: params[:player])
    if result.success?
      flash[:notice] = t(:gathers_user_pick)
    else
      flash[:error] = result.error.to_s
    end

    respond_to do |format|
      format.turbo_stream do
        @gatherer = @gather.gatherers.of_user(cuser).first if cuser
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
      format.html { redirect_to @gather }
    end
  end

  def version
    Rails.logger.silence do
      # Only the fields required by refresh + the version response are needed here.
      # Avoid Gather.basic (5 association JOINs) on every poll from 12 sessions.
      gather = Gather.find(params[:id])
      previous_status = gather.status
      gather.refresh(nil)
      Gathers::Broadcaster.call(gather) if gather.status != previous_status

      render json: { id: gather.id, version: gather.version }
    end
  end

  private

  def load_gather
    # No pessimistic lock here — lock(true) serialised every concurrent page-load
    # across all 12 browser sessions. refresh() acquires with_lock internally
    # only when it actually needs to write, so the outer lock is redundant.
    @gather = Gather.basic.find(params[:id])
    raise ActiveRecord::RecordNotFound, 'Gather not found' unless @gather

    @gather.refresh cuser

    @gatherer = @gather.gatherers.of_user(cuser).first if cuser
    update_gatherers
  end

  def update_gatherers
    # Update user that has left and came back
    return unless @gatherer && @gatherer.status == Gatherer::STATE_LEAVING

    @gatherer.update_attribute(:status, Gatherer::STATE_ACTIVE)
  end
end
