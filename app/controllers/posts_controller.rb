# frozen_string_literal: true

class PostsController < ApplicationController
  before_action :load_post, except: %i[new create]
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
    @post = Post.build_for_actor(params, cuser)
    raise AccessError unless @post.can_create? cuser

    respond_to do |format|
      if @post.save
        flash[:notice] = t(:posts_create)
        format.js
        format.html { redirect_to topic_path(@post.topic, anchor: "post_#{@post.id}") }
      else
        # For AJAX/fast reply, render errors as JSON/JS
        @newpost = @post
        format.js { render :create_error }
        format.html do
          flash.now[:alert] = t(:please_fix_errors, default: 'Please fix the errors below.')
          render :new, status: :unprocessable_entity
        end
      end
    end
  end

  def update
    raise AccessError unless @post.can_update? cuser, params[:post]

    if @post.update(Post.params(params, cuser))
      flash[:notice] = t(:posts_update)
      redirect_to topic_path(@post.topic, anchor: "post_#{@post.id}")
    else
      flash.now[:alert] = t(:please_fix_errors, default: 'Please fix the errors below.')
      render :edit, status: :unprocessable_entity
    end
  end

  def trash
    raise AccessError unless @post.can_destroy? cuser

    @post.trash
    flash[:notice] = t(:posts_trash)
    path = if @post.topic&.persisted?
             polymorphic_path(@post.topic)
           else
             polymorphic_path(@post.topic.forum)
           end
    safe_redirect_to(path)
  end

  def destroy
    raise AccessError unless @post.can_destroy? cuser

    @post.destroy
    flash[:notice] = t(:posts_destroy)
    path = if @post.topic&.persisted?
             polymorphic_path(@post.topic)
           else
             polymorphic_path(@post.topic.forum)
           end
    safe_redirect_to(path)
  end

  private

  def load_post
    @post = Post.find(params[:id])
  end
end
