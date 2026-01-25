class ShoutmsgsController < ApplicationController
  respond_to :html, :js, :turbo_stream

  def index
    @shoutmsgs = Shoutmsg.typebox
  end

  def show
    @shoutmsgs = if params[:id2]
                   Shoutmsg.recent.of_object(params[:id], params[:id2]).reverse
                 else
                   Shoutmsg.recent.box
                 end
  end

  def create
    @shoutmsg = Shoutmsg.new(Shoutmsg.params(params, cuser))
    @shoutmsg.user = cuser
    Rails.logger.debug "Shoutmsgs#create params=#{params[:shoutmsg].inspect} cuser_id=#{cuser&.id}"
    raise AccessError unless @shoutmsg.can_create? cuser

    respond_to do |format|
      if @shoutmsg.save
        format.turbo_stream do
          Rails.logger.debug "Shoutmsgs#create saved id=#{@shoutmsg.id} user_id=#{@shoutmsg.user_id}"
          new_shout = Shoutmsg.new(shoutable_type: @shoutmsg.shoutable_type, shoutable_id: @shoutmsg.shoutable_id)
          render turbo_stream: turbo_stream.replace("new_#{@shoutmsg.domain}", partial: 'shoutmsgs/new',
                                                                               locals: { shoutmsg: new_shout })
        end
        format.html { redirect_to_back }
      else
        format.turbo_stream do
          Rails.logger.debug "Shoutmsgs#create save failed: #{@shoutmsg.errors.full_messages.join(', ')}"
          flash.now[:error] =
            @shoutmsg.errors.full_messages.any? ? @shoutmsg.errors.full_messages.join(', ') : t(:invalid_message)
          streams = []
          streams << turbo_stream.replace("new_#{@shoutmsg.domain}", partial: 'shoutmsgs/new',
                                                                     locals: { shoutmsg: @shoutmsg })
          # Replace notification area so flash.now[:error] is shown to the user
          streams << turbo_stream.replace('notification', partial: 'application/messages')
          render turbo_stream: streams
        end
        format.html do
          flash[:error] = t(:invalid_message)
          redirect_to_back
        end
      end
    end
  end

  def destroy
    @shoutmsg = Shoutmsg.find params[:id]
    raise AccessError unless @shoutmsg.can_destroy? cuser

    @shoutmsg.destroy
    redirect_to_back
  end
end
