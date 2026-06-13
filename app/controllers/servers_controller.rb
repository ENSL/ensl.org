class ServersController < ApplicationController
  before_action :get_server, except: %i[index refresh new create]

  def index
    @servers = Server.hlds.active.ordered.includes(:user, :versions).all
    @ns2 = Server.ns2.active.ordered.includes(:user, :versions).all
    @officials = Server.ns2.active.ordered.where(['name LIKE ?', '%NSL%']).includes(:versions)
  end

  def show
  end

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
      flash[:notice] = t(:server_create)
      redirect_to @server
    else
      respond_with_validation_errors(@server, template: :new)
    end
  end

  def update
    raise AccessError unless @server.can_update? cuser

    if @server.update(Server.params(params, cuser))
      flash[:notice] = t(:server_update)
      redirect_to @server
    else
      respond_with_validation_errors(@server, template: :edit)
    end
  end

  def destroy
    raise AccessError unless @server.can_destroy? cuser

    return unless @server.destroy

    flash[:notice] = t(:server_destroy)
    redirect_to servers_url
  end

  private

  def get_server
    @server = Server.find params[:id]
    return if @server.active? || @server.can_update?(cuser)

    raise ActiveRecord::RecordNotFound
  end
end
