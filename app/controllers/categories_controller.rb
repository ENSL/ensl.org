class CategoriesController < ApplicationController
  before_action :get_category, except: [:index, :new, :create]

  def show
    if [Category::DOMAIN_ARTICLES, Category::DOMAIN_NEWS].include? @category.domain
      @articles = Article.with_comments.ordered.limited.nodrafts.category params[:id]
      Category.find(params[:id]).mark_as_read! for: cuser if cuser
      render partial: 'articles/article', collection: @articles.to_a
    end
  end

  def index
    @categories = Category.ordered
  end

  def new
    @category = Category.new
    raise AccessError unless @category.can_create? cuser
  end

  def edit
    raise AccessError unless @category.can_update? cuser
  end

  def create
    @category = Category.new Category.params(params, cuser)
    raise AccessError unless @category.can_create? cuser

    if @category.save
      # FIXME: move to model
      @category.update_attribute :sort, @category.id
      flash[:notice] = t(:articles_category)
      redirect_to :categories
    else
      render action: :new
    end
  end

  def update
    raise AccessError unless @category.can_update? cuser
    if @category.update_attributes Category.params(params, cuser)
      flash[:notice] = t(:articles_category_update)
      redirect_to :categories
    end
  end

  def up
    raise AccessError unless @category.can_update? cuser
    @category.move_up(["domain = ?", @category.domain], "sort")
    redirect_to :categories
  end

  def down
    raise AccessError unless @category.can_update? cuser
    @category.move_down(["domain = ?", @category.domain], "sort")
    redirect_to :categories
  end

  def destroy
    raise AccessError unless @category.can_destroy? cuser
    @category.destroy
    redirect_to :categories
  end

  private

  def get_category
    @category = Category.find params[:id]
  end
end
