# frozen_string_literal: true

class CategoriesController < ApplicationController
  before_action :load_category, except: %i[index new create]

  def show
    return unless [Category::DOMAIN_ARTICLES, Category::DOMAIN_NEWS].include? @category.domain

    @articles = Article.with_comments.ordered.limited.nodrafts.category params[:id]
    @category.mark_as_read! for: cuser if cuser
    render partial: 'articles/article', collection: @articles.to_a
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
      flash[:notice] = t(:articles_category)
      redirect_to :categories
    else
      respond_with_validation_errors(@category, template: :new)
    end
  end

  def update
    raise AccessError unless @category.can_update? cuser

    if @category.update Category.params(params, cuser)
      flash[:notice] = t(:articles_category_update)
      redirect_to :categories
    else
      respond_with_validation_errors(@category, template: :edit)
    end
  end

  def up
    raise AccessError unless @category.can_update? cuser

    @category.move_up(Category.where(domain: @category.domain), 'sort')
    redirect_to :categories
  end

  def down
    raise AccessError unless @category.can_update? cuser

    @category.move_down(Category.where(domain: @category.domain), 'sort')
    redirect_to :categories
  end

  def destroy
    raise AccessError unless @category.can_destroy? cuser

    @category.destroy
    redirect_to :categories
  end

  private

  def load_category
    @category = Category.find params[:id]
  end
end
