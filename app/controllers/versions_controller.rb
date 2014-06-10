class VersionsController < ApplicationController
  before_filter :get_article

  def index
    @versions = @article.versions
    render 'articles/history'
  end

  def show
    raise AccessError unless cuser and cuser.admin?
    @version = @article.versions.find params[:id]
    @nobody = true
    render 'articles/version'
  end

  def update
    raise AccessError unless @article.can_update? cuser
    @version = @article.versions.find params[:id]
    @nobody = true

    if @article.revert_to! @version.version
      flash[:notice] = t(:articles_revert, :version => @version.version)
    end

    redirect_to @article
  end

  private

  def get_article
    @article = Article.find(params[:article_id])
  end
end
