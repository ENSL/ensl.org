# frozen_string_literal: true

class ForumsController < ApplicationController
  before_action :load_forum, only: %i[show edit update up down destroy]
  layout 'forums'

  def index
    @categories = Category.domain(Category::DOMAIN_FORUMS).ordered
    @nobody = true
  end

  def show
    raise AccessError unless @forum.can_show? cuser

    @topics = Topic.for_forum_overview(@forum).paginate(page: params[:page], per_page: 30)

    @forum.mark_as_read! for: cuser if cuser
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
    @forum = Forum.new(Forum.params(params, cuser))
    raise AccessError unless @forum.can_create? cuser

    if @forum.save
      flash[:notice] = flash_action_message(:create, @forum)
      redirect_to(@forum)
    else
      render :new
    end
  end

  def update
    raise AccessError unless @forum.can_update? cuser

    if @forum.update(Forum.params(params, cuser))
      flash[:notice] = flash_action_message(:update, @forum)
      redirect_to(@forum)
    else
      render :edit
    end
  end

  def up
    raise AccessError unless @forum.can_update? cuser

    @forum.move_up(@forum.category.forums)
    redirect_to_back
  end

  def down
    raise AccessError unless @forum.can_update? cuser

    @forum.move_down(@forum.category.forums)
    redirect_to_back
  end

  def destroy
    raise AccessError unless @forum.can_destroy? cuser

    @forum.destroy
    redirect_to(forums_url)
  end

  private

  def load_forum
    @forum = Forum.find(params[:id])
  end
end
