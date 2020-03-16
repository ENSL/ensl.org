class MapsController < ApplicationController
  before_action :get_map, only: [:show, :edit, :update, :destroy]

  def index
    @maps = Map.basic
  end

  def show
  end

  def new
    @map = Map.new
    raise AccessError unless @map.can_create? cuser
  end

  def edit
    raise AccessError unless @map.can_update? cuser
  end

  def create
    @map = Map.new params[:map]
    raise AccessError unless @map.can_create? cuser

    if @map.save
      flash[:notice] = t(:maps_create)
      redirect_to @map
    else
      render :new
    end
  end

  def update
    raise AccessError unless @map.can_update? cuser
    if @map.update_attributes(params[:map])
      flash[:notice] = t(:maps_update)
      redirect_to @map
    else
      render :edit
    end
  end

  def destroy
    raise AccessError unless @map.can_destroy? cuser
    @map.destroy
    redirect_to(maps_url)
  end

  private

  def get_map
    @map = Map.find params[:id]
  end
end
