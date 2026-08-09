# frozen_string_literal: true

class MoviesController < ApplicationController
  before_action :load_movie, except: %i[index new create admin]
  before_action :load_movie_categories, only: %i[new edit create update]
  respond_to :html, :turbo_stream
  helper_method :vlc_installer_file

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
    @movie.record_view_count(request.remote_ip, logged_in: cuser.nil?)
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
  end

  def edit
    raise AccessError unless @movie.can_update? cuser
  end

  def create
    @movie = Movie.new(Movie.params(params, cuser))
    @movie.user ||= cuser
    raise AccessError unless @movie.can_create? cuser

    if @movie.save
      flash[:notice] = flash_action_message(:create, @movie)
      redirect_to(@movie)
    else
      respond_with_validation_errors(@movie, template: :new)
    end
  end

  def update
    raise AccessError unless @movie.can_update? cuser

    if @movie.update(filtered_movie_params)
      flash[:notice] = flash_action_message(:update, @movie)
      redirect_to(@movie)
    else
      respond_with_validation_errors(@movie, template: :edit)
    end
  end

  def preview
    raise AccessError unless @movie.can_update? cuser

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

    success = @movie.make_snapshot(seconds: snapshot_seconds)
    respond_to do |format|
      format.turbo_stream do
        apply_movie_snapshot_flash(success, flash.now)
        render turbo_stream: turbo_stream.replace('notification', partial: 'application/messages')
      end
      format.html do
        apply_movie_snapshot_flash(success, flash)
        redirect_to edit_movie_path(@movie)
      end
    end
  end

  def download
    raise AccessError unless cuser&.admin?

    @movie.stream_ip = params[:ip]
    @movie.stream_port = params[:port]
    render html: helpers.safe_join(
      [
        ERB::Util.html_escape(t(:executed)),
        helpers.tag.br,
        ERB::Util.html_escape(@movie.make_stream.to_s)
      ]
    ), layout: true
  end

  def destroy
    raise AccessError unless @movie.can_destroy? cuser

    @movie.destroy
    redirect_to(movies_url)
  end

  private

  def vlc_installer_file
    @vlc_installer_file ||= DataFile.find(855)
  end

  def load_movie
    @movie = Movie.find(params[:id])
  end

  def load_movie_categories
    @movie_categories = Category.options_for_select(Category.domain(Category::DOMAIN_MOVIES))
  end

  def filtered_movie_params
    movie_params = Movie.params(params, cuser)
    return movie_params if movie_params[:file_id].present?

    movie_params.except(:file_id)
  end

  def snapshot_seconds
    raw = params[:secs].to_s.strip
    seconds = raw.present? ? Float(raw) : nil
    seconds&.negative? ? nil : seconds
  rescue ArgumentError, TypeError
    nil
  end

  def apply_movie_snapshot_flash(success, flash_store)
    flash_store[success ? :notice : :alert] = success ? 'Snapshot created.' : 'Snapshot could not be created.'
  end
end
