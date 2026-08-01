# frozen_string_literal: true

class ArticlesController < ApplicationController
  before_action :load_article, only: %i[show edit update cleanup destroy]

  def index
    @categories = Category.ordered.nospecial.domain Category::DOMAIN_ARTICLES
  end

  def news_index
    @news = Article.with_comments.ordered.nodrafts.news.limit(10)
    @categories = Category.ordered.domain(Category::DOMAIN_NEWS)
  end

  def news_archive
    @news = Article.with_comments.ordered.nodrafts.news
  end

  def admin
    raise AccessError unless cuser&.admin?

    @articles = { 'Drafts' => Article.drafts.ordered, 'Special' => Article.category(Category::SPECIAL).ordered }
  end

  def show
    raise AccessError unless @article.can_show? cuser

    @article.mark_as_read! for: cuser if cuser
    @article.record_view_count(request.remote_ip, logged_in: cuser.nil?)
  end

  def new
    @article = Article.new
    raise AccessError unless @article.can_create? cuser
  end

  def edit
    raise AccessError unless @article.can_update? cuser

    @file = DataFile.new
    @file.directory_id = Directory::ARTICLES
    @file.article = @article
  end

  def create
    @article = Article.new(Article.article_params(params, cuser))
    @article.user = cuser
    raise AccessError unless @article.can_create? cuser

    if @article.save
      flash[:notice] = t(:articles_create)
      redirect_to @article
    else
      respond_with_validation_errors(@article, template: :new)
    end
  end

  def update
    raise AccessError unless @article.can_update?(cuser, Article.article_params(params, cuser))

    if @article.update(Article.article_params(params, cuser))
      flash[:notice] = t(:articles_update)
      redirect_to @article
    else
      respond_with_validation_errors(@article, template: :edit)
    end
  end

  # TODO: link it somewhere
  def cleanup
    raise AccessError unless @article.can_update? cuser

    @article.text = strip(@article.text)
    @article.save!
    redirect_to @article
  end

  def destroy
    raise AccessError unless @article.can_destroy? cuser

    @article.destroy
    redirect_to_back
  end

  private

  def load_article
    @article = Article.find params[:id]
  end
end
