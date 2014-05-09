class ForumsController < ApplicationController
  before_filter :get_forum, only: [:show, :edit, :update, :up, :down, :destroy]
  layout 'forums'

  def index
    @categories = Category.domain(Category::DOMAIN_FORUMS).ordered
    @nobody = true
  end

  def show
    raise AccessError unless @forum.can_show? cuser

    @topics = Topic.where(forum_id: @forum.id)
    .joins(:posts, :user, :users_who_read)
    .includes(:lock)
    .group('topics.id')
    .order('state DESC, posts.id DESC')
    .paginate(page: params[:page], per_page: 30)

    @forum.read_by! cuser if cuser
    @nobody = true
  end

  def new
    @forum = Forum.new
    raise AccessError unless @forum.can_create? cuser
  end

  def edit
    raise AccessError unless @forum.can_update? cuser
  end

  def create
    @forum = Forum.new(params[:forum])
    raise AccessError unless @forum.can_create? cuser

    if @forum.save
      flash[:notice] = t(:forums_create)
      redirect_to(@forum)
    else
      render :new
    end
  end

  def update
    raise AccessError unless @forum.can_update? cuser
    if @forum.update_attributes(params[:forum])
      flash[:notice] = t(:forums_update)
      redirect_to(@forum)
    else
      render :edit
    end
  end

  def up
    raise AccessError unless @forum.can_update? cuser
    @forum.move_up(category_id: @forum.category.id)
    redirect_to_back
  end

  def down
    raise AccessError unless @forum.can_update? cuser
    @forum.move_down(category_id: @forum.category.id)
    redirect_to_back
  end

  def destroy
    raise AccessError unless @forum.can_destroy? cuser
    @forum.destroy
    redirect_to(forums_url)
  end

  private

  def get_forum
    @forum = Forum.find(params[:id])
  end
end
