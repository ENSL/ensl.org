class ServersController < ApplicationController
  before_filter :get_server, :except => [:index, :refresh, :new, :create]

  def refresh
    Server.refresh
    render :text => t(:servers_updated)
  end

  def index
    @servers = Server.hlds.active.ordered.all :include => :user
    @ns2 = Server.ns2.active.ordered.all :include => :user
    @hltvs = Server.hltvs.active.ordered.all :include => :user
    @officials = Server.ns2.active.ordered.where ["name LIKE ?", "%NSL%"]
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

  def admin
    @result = @server.execute params[:query] if params[:query]
    raise AccessError unless @server.can_update? cuser

    if request.xhr?
      render :partial => "response", :layout => false
    end
  end

  def create
    @server = Server.new params[:server]
    @server.user = cuser
    raise AccessError unless @server.can_create? cuser

    if @server.save
      flash[:notice] = t(:server_create)
      redirect_to @server
    else
      render :action => "new"
    end
  end

  def update
    raise AccessError unless @server.can_update? cuser

    if @server.update_attributes params[:server]
      flash[:notice] = t(:server_update)
      redirect_to @server
    else
      render :action => "edit"
    end
  end

  def default
    raise AccessError unless @server.can_update? cuser
    @server.default_record
    render :text => "Ok"
  end

  def destroy
    raise AccessError unless @server.can_destroy? cuser
    @server.destroy
    redirect_to(servers_url)
  end

  private

  def get_server
    @server = Server.find params[:id]
  end
end
