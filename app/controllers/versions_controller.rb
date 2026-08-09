# frozen_string_literal: true

class VersionsController < ApplicationController
  before_action :load_article
  before_action :ensure_versions_available
  before_action :build_version_history
  before_action :load_version, only: %i[show update]

  def index
    @versions = @version_history.versions
    @version_numbers = @version_history.version_numbers_for(@versions)
    @snapshots = @version_history.snapshots_for(@versions)
    render 'articles/history'
  end

  def show
    raise AccessError unless cuser&.admin?

    @snapshot = @version_history.snapshot_for(@version)
    @version_number = @version_history.version_number_for(@version)
    @nobody = true
    render 'articles/version'
  end

  def update
    raise AccessError unless @article.can_update? cuser

    version_number = @version_history.version_number_for(@version)
    @nobody = true

    flash[:notice] = t('articles.revert', version: version_number) if @version_history.revert_to!(@version)

    redirect_to @article
  end

  private

  def load_article
    @article = Article.find(params[:article_id])
  end

  def ensure_versions_available
    return if ActiveRecord::Base.connection.data_source_exists?('versions')

    raise ActiveRecord::RecordNotFound
  end

  def build_version_history
    @version_history = Articles::VersionHistory.new(@article)
  end

  def load_version
    @version = @article.versions.find(params[:id])
  end
end
