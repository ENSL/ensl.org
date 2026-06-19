# frozen_string_literal: true

class MoviesController < ApplicationController
  before_action :get_movie, except: %i[index new create admin]
  respond_to :html, :turbo_stream

  def index
    # Movie.filter_or_all expects (order, rating, size, author)
    @movies = Movie.filter_or_all(params[:order], params[:rating], params[:size], params[:author])
    # authors for dropdown (only users who submitted movies)
    @movie_authors = Movie.submitter_options
    # movie size categories for filter buttons
    @movie_size_categories = Category.movie_size_categories
    render layout: 'full'
  end

  def show
    @movie.mark_as_read! for: cuser if cuser
    @movie.record_view_count(request.remote_ip, cuser.nil?)
    return unless @movie.file&.related

    redirect_to data_file_path(@movie.file.related)
  end

  def refresh
    @movie.update_status
  end

  def admin
    raise AccessError unless cuser&.admin?

    @movies = Movie.includes(:user, :file, :preview).ordered.all
  end

  def new
    @movie = Movie.new
    raise Exceptions::UserRegistrationReq unless @movie.can_create? cuser

    @movie_categories = Category.options_for_select(Category.domain(Category::DOMAIN_MOVIES))
  end

  def edit
    raise AccessError unless @movie.can_update? cuser

    @movie_categories = Category.options_for_select(Category.domain(Category::DOMAIN_MOVIES))
  end

  def create
    @movie = Movie.new(Movie.params(params, cuser))
    @movie.user ||= cuser
    raise AccessError unless @movie.can_create? cuser

    if @movie.save
      flash[:notice] = t(:movies_create)
      redirect_to(@movie)
    else
      @movie_categories = Category.options_for_select(Category.domain(Category::DOMAIN_MOVIES))
      respond_with_validation_errors(@movie, template: :new)
    end
  end

  def update
    raise AccessError unless @movie.can_update? cuser

    @movie_categories = Category.options_for_select(Category.domain(Category::DOMAIN_MOVIES))
    movie_params = Movie.params(params, cuser)
    movie_params = movie_params.except(:file_id) if movie_params[:file_id].blank?

    if @movie.update(movie_params)
      flash[:notice] = t(:movies_update)
      redirect_to(@movie)
    else
      respond_with_validation_errors(@movie, template: :edit)
    end
  end

  def preview
    raise AccessError unless @movie.can_update? cuser

    # x = params[:x].to_i <= 1280 ? params[:x].to_i : 800
    # y = params[:y].to_i <= 720 ? params[:y].to_i : 600
    begin
      result = @movie.make_preview
      flash[:notice] = "#{t(:executed)} #{result}".html_safe
    rescue VideoProcessing::Error => e
      flash[:alert] = e.message.to_s
    end

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.replace('notification', partial: 'application/messages') }
      format.html { redirect_back(fallback_location: @movie) }
    end
  end

  def snapshot
    raise AccessError unless @movie.can_update? cuser

    seconds = begin
      raw = params[:secs].to_s.strip
      raw.present? ? Float(raw) : nil
    rescue ArgumentError, TypeError
      nil
    end
    seconds = nil if seconds&.negative?

    success = @movie.make_snapshot(seconds: seconds)
    notice_message = 'Snapshot created.'
    alert_message = 'Snapshot could not be created.'

    respond_to do |format|
      format.turbo_stream do
        if success
          flash.now[:notice] = notice_message
        else
          flash.now[:alert] = alert_message
        end

        render turbo_stream: turbo_stream.replace('notification', partial: 'application/messages')
      end
      format.html do
        if success
          flash[:notice] = notice_message
        else
          flash[:alert] = alert_message
        end

        redirect_to edit_movie_path(@movie)
      end
    end
  end

  def download
    raise AccessError unless cuser&.admin?

    @movie.stream_ip = params[:ip]
    @movie.stream_port = params[:port]
    render html: helpers.safe_join([
                                     ERB::Util.html_escape(t(:executed)),
                                     helpers.tag.br,
                                     ERB::Util.html_escape(@movie.make_stream.to_s)
                                   ]), layout: true
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
