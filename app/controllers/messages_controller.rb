# frozen_string_literal: true

class MessagesController < ApplicationController
  before_action :load_message, only: %i[show edit update destroy]

  def index
    raise AccessError unless cuser
  end

  def show
    raise AccessError unless @message.can_show? cuser

    @message.mark_as_read! for: cuser
    @messages = @message.thread
  end

  def new
    @message = Message.new
    raise AccessError unless @message.can_create? cuser

    @message.recipient = Message.recipient_for(params[:id], params[:id2])
    @message.title = params[:title]
  end

  def create
    @message = Message.new(Message.params(params, cuser))
    @message.sender = @message.sender_for(cuser)
    raise AccessError unless @message.can_create? cuser

    if @message.save
      flash[:notice] = t('messages.create.success')
      redirect_to(@message)
    else
      render :new
    end
  end

  private

  def load_message
    @message = Message.find(params[:id])
  end
end
