class MoviesController < ApplicationController
  before_action :get_movie, except: [:index, :new, :create]

  def index
    @movies = Movie.filter_or_all(params[:filter], params[:order])
  end

  def show
    @movie.mark_as_read! for: cuser if cuser
    @movie.record_view_count(request.remote_ip, cuser.nil?)
    redirect_to @movie.file.related if @movie.file and @movie.file.related
  end

  def refresh
    @movie.update_status
  end

  def new
    @movie = Movie.new
    raise AccessError unless @movie.can_create? cuser
  end

  def edit
    raise AccessError unless @movie.can_update? cuser
  end

  def create
    @movie = Movie.new(params[:movie])
    raise AccessError unless @movie.can_create? cuser

    if @movie.save
      flash[:notice] = t(:movies_create)
      redirect_to(@movie)
    else
      render :new
    end
  end

  def update
    raise AccessError unless @movie.can_update? cuser

    if @movie.update_attributes(params[:movie])
      flash[:notice] = t(:movies_update)
      redirect_to(@movie)
    else
      render :edit
    end
  end

  def preview
    raise AccessError unless @movie.can_update? cuser
    x = params[:x].to_i <= 1280 ? params[:x].to_i : 800
    y = params[:y].to_i <= 720 ? params[:y].to_i : 600
    render text: t(:executed) + "<br />" + @movie.make_preview(x, y), layout: true
  end

  def snapshot
    raise AccessError unless @movie.can_update? cuser
    secs = params[:secs].to_i > 0 ? params[:secs].to_i : 5
    render text: t(:executed) + "<br />" + @movie.make_snapshot(secs), layout: true
  end

  def download
    raise AccessError unless cuser.admin?
    @movie.stream_ip = params[:ip]
    @movie.stream_port = params[:port]
    render text: t(:executed) + "<br />" + @movie.make_stream, layout: true
  end

  def destroy
    raise AccessError unless @movie.can_destroy? cuser
    @movie.destroy
    redirect_to(movies_url)
  end

  private

  def get_movie
    @movie = Movie.find(params[:id])
  end
end
