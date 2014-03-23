class DirectoriesController < ApplicationController
  before_filter :get_directory, :except => [:new, :create]

  def show
    if @directory.hidden
      @files = @directory.files
      render :partial => "data_files/list", :layout => true
    else
      @directories = Directory.ordered.filtered.all :conditions => {:parent_id => 1}
    end
  end

  def new
    @directory = Directory.new
    @directory.parent = Directory.find params[:id]
    raise AccessError unless @directory.can_create? cuser
  end

  def edit
    raise AccessError unless @directory.can_update? cuser
  end

  def refresh
    @directory.process_dir
    render :text => t(:directories_update)
  end

  def create
    @directory = Directory.new params[:directory]
    raise AccessError unless @directory.can_create? cuser

    if @directory.save
      flash[:notice] = t(:directories_create)
      redirect_to(@directory)
    else
      render :action => "new"
    end
  end

  def update
    raise AccessError unless @directory.can_update? cuser
    if @directory.update_attributes(params[:directory])
      flash[:notice] = t(:directories_update)
      redirect_to @directory
    else
      render :action => "edit"
    end
  end

  def destroy
    raise AccessError unless @directory.can_destroy? cuser
    @directory.destroy
    redirect_to directories_url
  end

  private

  def get_directory
    @directory = Directory.find params[:id]
  end
end
