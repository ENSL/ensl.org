class PostsController < ApplicationController
  before_action :get_post, except: [:new, :create]
  respond_to :html, :js
  layout 'forums'

  def quote
    raise AccessError unless @post.can_show? cuser
  end

  def new
    @post = Post.new
    @post.topic = Topic.find(params[:id])
    raise AccessError unless @post.can_create? cuser
  end

  def edit
    raise AccessError unless @post.can_update? cuser
    render layout: 'forums'
  end

  def create
    @post = Post.new(Post.params(params, cuser))
    @post.user = cuser
    raise AccessError unless @post.can_create? cuser

    respond_to do |format|
      if @post.save
        flash[:notice] = t(:posts_create)
        format.js  { render }
        format.html { return_to }
      else
        format.html { render :new }
      end
    end
  end

  def update
    raise AccessError unless @post.can_update? cuser, params[:post]
    if @post.update_attributes(Post.params(params, cuser))
      flash[:notice] = t(:posts_update)
      redirect_to @post.topic
    else
      render :edit
    end
  end

  def trash
    raise AccessError unless @post.can_destroy? cuser
    @post.trash
    if @post.topic.exists?
      redirect_to @post.topic
    else
      redirect_to @post.topic.forum
    end
  end

  def destroy
    raise AccessError unless @post.can_destroy? cuser
    @post.destroy
    if @post.topic.exists?
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
