class DataFilesController < ApplicationController
  before_action :get_file, only: %i[show edit update destroy rate]
  before_action :prepare_edit_form_data, only: %i[edit update]
  respond_to :html, :turbo_stream

  def show; end

  def admin
    raise AccessError unless cuser and cuser.admin?

    @files = []
    DataFile.all.each do |f|
      @files << f unless File.exist?(f.path)
    end
    @movies = []
    DataFile.movies.each do |f|
      @movies << f unless f.movie or f.preview or (f.related and f.related.movie)
    end
  end

  def new
    @file = DataFile.new
    @file.directory = Directory.find params[:id]
    raise AccessError unless @file.can_create? cuser
  end

  def edit
    raise AccessError unless @file.can_update? cuser
  end

  def create
    @file = DataFile.new(DataFile.params(params, cuser))
    @file.size = 0
    raise AccessError unless @file.can_create? cuser

    if @file.save
      flash[:notice] = t(:files_create)
      created_movie = @file.movie || Movie.find_by(file_id: @file.id)
      if @file.article
        redirect_to @file.article
      elsif created_movie
        redirect_to created_movie
      else
        redirect_to @file
      end
    else
      respond_with_validation_errors(@file, template: :new)
    end
  end

  def update
    raise AccessError unless @file.can_update? cuser

    if @file.update(DataFile.params(params, cuser))
      flash[:notice] = t(:files_update)
      return_to = params[:return_to].to_s
      if return_to.start_with?('/') && !return_to.start_with?('//')
        redirect_to(return_to)
      else
        redirect_to(@file)
      end
    else
      respond_with_validation_errors(@file, template: :edit)
    end
  end

  def destroy
    raise AccessError unless @file.can_destroy? cuser

    @file.destroy
    redirect_to directory_path(@file.directory)
  end

  def rate
    raise AccessError unless cuser

    @file.rate_it(params[:id2], cuser.id) if params[:id2].to_i > 0 and params[:id2].to_i <= 5
    head :ok
  end

  def trash
    raise AccessError unless cuser and cuser.admin?

    deleted_files = []
    DataFile.all.each do |file|
      unless File.exist?(file.path)
        file.destroy
        deleted_files << ERB::Util.html_escape(file.to_s)
      end
    end
    render html: helpers.safe_join(deleted_files, helpers.tag.br), layout: true
  end

  private

  def get_file
    @file = DataFile.find params[:id]
  end

  def prepare_edit_form_data
    @available_related_files = DataFile.for_related_selection(@file)
    @add_related_options = @available_related_files.map do |file|
      suffix = file.related_files.any? ? " (+#{file.related_files.size} related files)" : ''
      ["#{file}#{suffix}", file.id]
    end
  end
end
