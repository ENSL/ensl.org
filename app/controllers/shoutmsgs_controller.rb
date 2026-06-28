# frozen_string_literal: true

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
    @shoutmsg = Shoutmsg.build_for_actor(params, cuser)
    Rails.logger.debug { "Shoutmsgs#create params=#{params[:shoutmsg].inspect} cuser_id=#{cuser&.id}" }
    raise AccessError unless @shoutmsg.can_create? cuser

    respond_to do |format|
      if @shoutmsg.save
        render_shoutmsg_create_success(format)
      else
        render_shoutmsg_create_failure(format)
      end
    end
  end

  def destroy
    @shoutmsg = Shoutmsg.find params[:id]
    raise AccessError unless @shoutmsg.can_destroy? cuser

    @shoutmsg.destroy
    redirect_to_back
  end

  private

  def render_shoutmsg_create_success(format)
    format.turbo_stream do
      render turbo_stream: turbo_stream.replace(
        "new_#{@shoutmsg.domain}",
        partial: 'shoutmsgs/new',
        locals: { shoutmsg: @shoutmsg.reset_form_shout }
      )
    end
    format.html { redirect_to_back }
  end

  def render_shoutmsg_create_failure(format)
    format.turbo_stream do
      flash.now[:error] = @shoutmsg.validation_error_message(t(:invalid_message))
      render turbo_stream: [
        turbo_stream.replace(
          "new_#{@shoutmsg.domain}",
          partial: 'shoutmsgs/new',
          locals: { shoutmsg: @shoutmsg }
        ),
        turbo_stream.replace('notification', partial: 'application/messages')
      ]
    end
    format.html do
      flash[:error] = t(:invalid_message)
      redirect_to_back
    end
  end
end
