class ArticlesController < ApplicationController
  before_filter :get_article, :only => [:show, :edit, :update, :cleanup, :destroy]

  def index
    @categories = Category.ordered.nospecial.domain Category::DOMAIN_ARTICLES
  end

  def news_index
    @news = Article.with_comments.ordered.limited.nodrafts.onlynews
    @categories = Category.ordered.domain(Category::DOMAIN_NEWS)
    @nobody = true
  end

  def news_archive
    @news = Article.with_comments.ordered.nodrafts.onlynews
  end

  def admin
    raise AccessError unless cuser and cuser.admin?
    @articles = {"Drafts" => Article.drafts.ordered, "Special" => Article.category(Category::SPECIAL).ordered}
  end

  def show
    raise AccessError unless @article.can_show? cuser
    @article.read_by! cuser if cuser
    # @article.record_view_count(request.remote_ip, cuser.nil?)
    @nobody = true
  end

  def new
    @article = Article.new
    @article.text_coding = Article::CODING_HTML
    raise AccessError unless @article.can_create? cuser
  end

  def edit
    raise AccessError unless @article.can_update? cuser
    @file = DataFile.new
    @file.directory_id = Directory::ARTICLES
    @file.article = @article
  end

  def create
    @article = Article.new params[:article]
    @article.user = cuser
    raise AccessError unless @article.can_create? cuser

    if @article.save
      flash[:notice] = t(:articles_create)
      redirect_to @article
    else
      render :action => "new"
    end
  end

  def update
    raise AccessError unless @article.can_update? cuser, params[:article]
    if @article.update_attributes params[:article]
      flash[:notice] = t(:articles_update)
      redirect_to @article
    else
      render :action => "edit"
    end
  end

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

  def get_article
    @article = Article.find params[:id]
  end
end
