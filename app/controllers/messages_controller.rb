class MessagesController < ApplicationController
  before_filter :get_message, only: [:show, :edit, :update, :destroy]

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

    case params[:id]
    when "User"
      @message.recipient = User.find(params[:id2])
    when "Team"
      @message.recipient = Team.find(params[:id2])
    when "Group"
      @message.recipient = Group.find(params[:id2])
    else
      raise Error, "Illegible recipient"
    end
    @message.title = params[:title]
  end

  def create
    @message = Message.new(params[:message])
    @message.sender = @message.sender_raw == "" ? cuser : cuser.active_teams.find(@message.sender_raw)
    raise AccessError unless @message.can_create? cuser

    if @message.save
      flash[:notice] = t(:message_create)
      redirect_to(@message)
    else
      render :new
    end
  end

  private

  def get_message
    @message = Message.find(params[:id])
  end
end
