class PostsController < ApplicationController
  before_filter :get_post, :except => [:new, :create]
  respond_to :html, :js

  def quote
    raise AccessError unless @post.can_show? cuser
  end

  def new
    @post = Post.new
    @post.topic = Topic.find(params[:id])
    raise AccessError unless @post.can_create? cuser
    render :layout => "forums"
  end

  def edit
    raise AccessError unless @post.can_update? cuser
    render :layout => "forums"
  end

  def create
    @post = Post.new(params[:post])
    @post.user = cuser
    raise AccessError unless @post.can_create? cuser

    respond_to do |format|
      if @post.save
        flash[:notice] = t(:posts_create)
        format.js  { render }
      else
        flash[:error] = t(:posts_invalid) + @post.errors.full_messages.to_s
        format.html { return_to }
      end
    end
  end

  def update
    raise AccessError unless @post.can_update? cuser, params[:post]
    if @post.update_attributes(params[:post])
      flash[:notice] = t(:posts_update)
      redirect_to @post.topic
    else
      render :action => "edit"
    end
  end

  def trash
    raise AccessError unless @post.can_destroy? cuser
    @post.trash
    if Topic.exists? @post.topic
      redirect_to @post.topic
    else
      redirect_to @post.topic.forum
    end
  end

  def destroy
    raise AccessError unless @post.can_destroy? cuser
    @post.destroy
    if Topic.exists? @post.topic
      redirect_to @post.topic
    else
      redirect_to @post.topic.forum
    end
  end

  private

  def get_post
    @post = Post.find(params[:id])
  end
end
