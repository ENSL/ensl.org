# frozen_string_literal: true

class DirectoriesController < ApplicationController
  before_action :load_directory, except: %i[new create]
  respond_to :html, :turbo_stream

  def show
    if @directory.hidden
      @files = @directory.files
      render partial: 'data_files/list', locals: { files: @files }
    else
      @directories = Directory.ordered.filtered.where(parent_id: Directory::ROOT)
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

  def reconcile
    raise AccessError unless @cuser&.admin?

    # Call reconciliation service
    service = DirectoryReconciliationService.new(@directory)
    @result = service.call.string

    respond_to do |format|
      format.html { render :reconcile, layout: 'full' }
      format.turbo_stream { render :reconcile, formats: [:html] }
    end
  end

  def create
    @directory = Directory.new(Directory.params(params, cuser))
    raise AccessError unless @directory.can_create? cuser

    if @directory.save
      flash[:notice] = t(:directories_create)
      redirect_to(@directory)
    else
      respond_with_validation_errors(@directory, template: :new)
    end
  end

  def update
    raise AccessError unless @directory.can_update? cuser

    if @directory.update(Directory.params(params, cuser))
      flash[:notice] = t(:directories_update)
      redirect_to @directory
    else
      respond_with_validation_errors(@directory, template: :edit)
    end
  end

  def destroy
    raise AccessError unless @directory.can_destroy? cuser

    @directory.destroy
    redirect_to directory_path(Directory.find(Directory::ROOT))
  end

  private

  def load_directory
    @directory = Directory.find params[:id]
  end
end
