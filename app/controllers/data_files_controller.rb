# frozen_string_literal: true

class DataFilesController < ApplicationController
  before_action :load_file, only: %i[show edit update destroy rate]
  before_action :prepare_edit_form_data, only: %i[edit update]
  respond_to :html, :turbo_stream

  def show; end

  def admin
    raise AccessError unless cuser&.admin?

    @files = DataFile.missing
    @movies = DataFile.movies_without_video
  end

  def new
    @file = DataFile.new
    directory_id = params[:directory_id].presence || params[:id].presence || Directory::ROOT
    @file.directory = Directory.find(directory_id)
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
      respond_to_successful_create
    else
      respond_to_failed_create
    end
  end

  def update
    raise AccessError unless @file.can_update? cuser

    if @file.update(DataFile.params(params, cuser))
      flash[:notice] = flash_action_message(:update, @file)
      redirect_to(safe_return_to || @file)
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

    @file.rate_it(params[:id2], cuser.id) if params[:id2].to_i.positive? && (params[:id2].to_i <= 5)
    head :ok
  end

  def trash
    raise AccessError unless cuser&.admin?

    deleted_files = DataFile.missing.map do |file|
      file.destroy
      ERB::Util.html_escape(file.to_s)
    end
    render html: helpers.safe_join(deleted_files, helpers.tag.br), layout: true
  end

  private

  def respond_to_successful_create
    respond_to do |format|
      format.html do
        flash[:notice] = flash_action_message(:create, @file)
        check_downloadability
        redirect_to redirect_target_after_create_path(@file)
      end
      format.turbo_stream do
        flash.now[:notice] = flash_action_message(:create, @file)
        check_downloadability
        prepare_article_file_response
      end
    end
  end

  def respond_to_failed_create
    respond_to do |format|
      format.html { respond_with_validation_errors(@file, template: :new) }
      format.turbo_stream do
        flash.now[:error] = @file.errors.full_messages.to_sentence
        prepare_article_file_response
        render :create, status: :unprocessable_content
      end
    end
  end

  def check_downloadability
    origin = DataFile.public_download_origin
    return if origin.blank? || @file.downloadable_from?(origin)

    flash[:alert] = 'File uploaded successfully, but its download URL is not currently reachable.'
  end

  def load_file
    @file = DataFile.find params[:id]
  end

  def prepare_edit_form_data
    @add_related_options = DataFile.related_selection_options(@file)
  end

  def prepare_article_file_response
    @article = @file.article
    raise ActionController::UnknownFormat unless @article

    @uploaded_file = @file if @file.persisted?
    @file = DataFile.new(directory_id: Directory::ARTICLES, article: @article) if @file.persisted?
  end

  def safe_return_to
    return_to = params[:return_to].to_s
    return_to if return_to.start_with?('/') && !return_to.start_with?('//')
  end

  def redirect_target_after_create_path(file)
    case (target = file.redirect_target_after_create)
    when Article
      article_path(target)
    when Movie
      movie_path(target)
    when DataFile
      data_file_path(target)
    else
      data_file_path(file)
    end
  end
end
