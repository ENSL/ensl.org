# frozen_string_literal: true

class CommentsController < ApplicationController
  before_action :load_comment, only: %i[raw quote edit update destroy]
  respond_to :html, :js

  def index
    @comments = Comment.recent(50).filtered
  end

  def show
    @comments = Comment.recent5.where(commentable_id: params[:id2], commentable_type: params[:id])
    render partial: 'list', layout: false, locals: { comments: @comments }
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
        flash[:notice] = flash_action_message(:create, @comment)
        format.js { render }
      else
        flash[:error] = "#{t('comments.invalid')} #{@comment.errors.full_messages.to_sentence}".strip
        format.html { redirect_back fallback_location: root_path }
      end
    end
  end

  def update
    raise AccessError unless @comment.can_update? cuser

    if @comment.update(Comment.params(params, cuser))
      flash[:notice] = flash_action_message(:update, @comment)
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
    respond_to do |format|
      format.html { render :quote, formats: :js }
      format.js
    end
  end

  private

  def load_comment
    @comment = Comment.find params[:id]
  end
end
