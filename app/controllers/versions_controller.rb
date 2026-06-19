# frozen_string_literal: true

class VersionsController < ApplicationController
  before_action :load_article
  before_action :ensure_versions_available

  def index
    @versions = @article.versions
    render 'articles/history'
  end

  def show
    raise AccessError unless cuser&.admin?

    @version = @article.versions.find params[:id]
    @nobody = true
    render 'articles/version'
  end

  def update
    raise AccessError unless @article.can_update? cuser

    @version = @article.versions.find params[:id]
    @nobody = true

    flash[:notice] = t(:articles_revert, version: @version.version) if @article.revert_to! @version.version

    redirect_to @article
  end

  private

  def load_article
    @article = Article.find(params[:article_id])
  end

  def ensure_versions_available
    return if ActiveRecord::Base.connection.data_source_exists?('article_versions')

    raise ActiveRecord::RecordNotFound
  end
end
