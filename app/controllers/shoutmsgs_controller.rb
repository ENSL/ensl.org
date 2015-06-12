class ShoutmsgsController < ApplicationController
  respond_to :html, :js

  def index
    @shoutmsgs = Shoutmsg.lastXXX.typebox
  end

  def show
    if params[:id2]
      @shoutmsgs = Shoutmsg.recent.of_object(params[:id], params[:id2]).reverse
    else
      @shoutmsgs = Shoutmsg.recent.box
    end
  end

  def create
    @shoutmsg = Shoutmsg.new params[:shoutmsg]
    puts @shoutmsg
    @shoutmsg.user = cuser
    raise AccessError unless @shoutmsg.can_create? cuser

    unless @shoutmsg.save
      flash[:error] = t(:invalid_message)
    end
  end

  def destroy
    @shoutmsg = Shoutmsg.find params[:id]
    raise AccessError unless @shoutmsg.can_destroy? cuser
    @shoutmsg.destroy
    redirect_to_back
  end
end
