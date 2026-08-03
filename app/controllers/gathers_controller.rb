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

  def edit; end

  def create
    @gather = Gather.new(category_id: params.dig(:gather, :category_id))
    raise AccessError unless @gather.can_create? cuser

    flash[:notice] = t(:gather_create) if @gather.save

    redirect_to_back
  end

  def update
    raise AccessError unless @gather.can_update? cuser

    flash[:notice] = 'Gather was successfully updated.' if @gather.admin_update(Gather.params(params, cuser))

    redirect_to @gather
  end

  # Desync failsafe for the Gatherer client. Updates are normally pushed live via
  # Turbo Streams/ActionCable (see Gathers::Broadcaster), but the client also polls
  # this endpoint every 5 seconds and reloads if the version has changed, in case a
  # broadcast was missed (e.g. dropped cable connection).
  def version
    Rails.logger.silence do
      # Only the fields required by refresh + the version response are needed here.
      # Avoid Gather.basic (5 association JOINs) on every poll from 12 sessions.
      gather = Gather.find(params[:id])
      gather.refresh_and_broadcast_if_status_changed!

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
    @gatherer&.reactivate_if_returning!
  end
end
