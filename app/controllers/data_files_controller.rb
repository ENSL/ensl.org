class DataFilesController < ApplicationController
  before_filter :get_file, :only => ['show', 'edit', 'update', 'destroy', 'rate', :addFile, :delFile]

  def show
  end

  def admin
    raise AccessError unless cuser and cuser.admin?
    @files = []
    DataFile.all.each do |f|
      @files << f unless File.exists?(f.path)
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
    @file = DataFile.new params[:data_file]
    @file.size = 0
    raise AccessError unless @file.can_create? cuser

    if @file.save
      flash[:notice] = t(:files_create)
      if @file.article
        redirect_to @file.article
      elsif @file.movie
        redirect_to @file.movie
      else
        redirect_to @file
      end
    else
      render :action => "new"
    end
  end

  def update
    raise AccessError unless @file.can_update? cuser
    if @file.update_attributes params[:data_file]
      flash[:notice] = t(:files_update)
      redirect_to(@file)
    else
      render :action => "edit"
    end
  end

  def addFile
    raise AccessError unless @file.can_update? cuser
    @related = @file.directory.files.not(@file).find params[:data_file][:related_id]
    @related.related = @file
    @related.save
    redirect_to edit_data_file_url(@file)
  end

  def delFile
    raise AccessError unless @file.can_update? cuser
    @related = @file.related_files.first params[:related_id]
    @related.related = nil
    @related.save
    redirect_to edit_data_file_url(@file)
  end

  def destroy
    raise AccessError unless @file.can_destroy? cuser
    @file.destroy
    redirect_to_back
  end

  def rate
    raise AccessError unless cuser
    if params[:id2].to_i > 0 and params[:id2].to_i <= 5
      @file.rate_it(params[:id2], cuser.id)
    end
    head :ok
  end

  def trash
    raise AccessError unless cuser and cuser.admin?
    @result = ""
    DataFile.all.each do |file|
      unless File.exists?(file.path)
        file.destroy
        @result << file.to_s + "<br />"
      end
    end
    render :text => @result, :layout => true
  end

  private

  def get_file
    @file = DataFile.find params[:id]
  end
end
