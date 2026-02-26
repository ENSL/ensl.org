class DataFilesController < ApplicationController
  before_action :get_file, only: %i[show edit update destroy rate addFile delFile]
  respond_to :html, :turbo_stream

  def show
  end

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

    @related_file_options = related_file_options
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
      redirect_to(@file)
    else
      respond_with_validation_errors(@file, template: :edit)
    end
  end

  def addFile
    raise AccessError unless @file.can_update? cuser

    @related = @file.directory.files.except_file(@file).find(params[:data_file][:related_id])
    @related.update!(related: @file)
    redirect_to edit_data_file_url(@file)
  rescue ActiveRecord::RecordInvalid
    @related_file_options = related_file_options
    @file.errors.add(:base, 'Could not add related file')
    render :edit, status: :unprocessable_entity
  end

  def delFile
    raise AccessError unless @file.can_update? cuser

    @related = @file.related_files.find params[:related_id]
    @related.related = nil
    @related.save
    redirect_to edit_data_file_url(@file)
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

    @result = ''
    DataFile.all.each do |file|
      unless File.exist?(file.path)
        file.destroy
        @result << file.to_s + '<br />'
      end
    end
    render text: @result, layout: true
  end

  private

  def get_file
    @file = DataFile.find params[:id]
  end

  def related_file_options
    @file.directory.files.except_file(@file).includes(:related_files).map do |file|
      suffix = file.related_files.any? ? " (+#{file.related_files.size} related files)" : ''
      ["#{file}#{suffix}", file.id]
    end
  end
end
