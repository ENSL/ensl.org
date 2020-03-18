class CommentsController < ApplicationController
  before_action :get_comment, only: [:raw, :quote, :edit, :update, :destroy]
  respond_to :html, :js

  def index
    @comments = Comment.recent.filtered
  end

  def show
    @comments = Comment.recent5.all conditions: { commentable_id: params[:id2], commentable_type: params[:id] }
    render partial: 'list', layout: false
  end

  def edit
    raise AccessError unless @comment.can_update? cuser
  end

  def create
    @comment = Comment.new(Comment.params(params, cuser))
    @comment.user = cuser
    raise AccessError unless @comment.can_create? cuser

    respond_to do |format|
      if @comment.save
        flash[:notice] = t(:comments_create)
        format.js { render }
      else
        flash[:error] = t(:comments_invalid) + @comment.errors.full_messages.to_s
        format.html { redirect_to(:back)}
      end
    end
  end

  def update
    raise AccessError unless @comment.can_update? cuser
    if @comment.update_attributes(Comment.params(parmas, cuser))
      flash[:notice] = t(:comments_update)
      return_to
    else
      render :edit
    end
  end

  def destroy
    raise AccessError unless @comment.can_destroy? cuser
    @comment.destroy
    redirect_to_back
  end

  def quote
  end

  private

  def get_comment
    @comment = Comment.find params[:id]
  end
end
