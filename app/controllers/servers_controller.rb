# frozen_string_literal: true

class ServersController < ApplicationController
  before_action :load_server, except: %i[index refresh new create]

  def index
    @servers = Server.hlds.active.ordered.includes(:user, :versions).all
    @ns2 = Server.ns2.active.ordered.includes(:user, :versions).all
    @officials = Server.ns2.active.ordered.where(['name LIKE ?', '%NSL%']).includes(:versions)
  end

  def show; end

  def new
    @server = Server.new
    raise AccessError unless @server.can_create? cuser
  end

  def edit
    raise AccessError unless @server.can_update? cuser
  end

  def create
    @server = Server.new(Server.params(params, cuser))
    @server.user = cuser
    raise AccessError unless @server.can_create? cuser

    if @server.save
      flash[:notice] = flash_action_message(:create, @server)
      redirect_to @server
    else
      respond_with_validation_errors(@server, template: :new)
    end
  end

  def update
    raise AccessError unless @server.can_update? cuser

    if @server.update(Server.params(params, cuser))
      flash[:notice] = flash_action_message(:update, @server)
      redirect_to @server
    else
      respond_with_validation_errors(@server, template: :edit)
    end
  end

  def destroy
    raise AccessError unless @server.can_destroy? cuser

    return unless @server.destroy

    flash[:notice] = flash_action_message(:destroy, @server)
    redirect_to servers_url
  end

  private

  def load_server
    @server = Server.find params[:id]
    return if @server.active? || @server.can_update?(cuser)

    raise ActiveRecord::RecordNotFound
  end
end
