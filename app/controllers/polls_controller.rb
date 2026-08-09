# frozen_string_literal: true

class PollsController < ApplicationController
  before_action :load_poll, except: %i[index new create]

  def index
    @polls = Poll.recent
  end

  def show; end

  def new
    @poll = Poll.new
    @poll.options.build
    raise AccessError unless @poll.can_create? cuser
  end

  def edit
    raise AccessError unless @poll.can_update? cuser
  end

  def create
    @poll = Poll.new(Poll.params(params, cuser))
    @poll.user = cuser
    raise AccessError unless @poll.can_create? cuser

    if @poll.save
      flash[:notice] = flash_action_message(:create, @poll)
      redirect_to @poll
    else
      render :new
    end
  end

  def update
    raise AccessError unless @poll.can_update? cuser

    if @poll.update(Poll.params(params, cuser))
      flash[:notice] = flash_action_message(:update, @poll)
      redirect_to @poll
    else
      render :edit
    end
  end

  def destroy
    raise AccessError unless @poll.can_destroy? cuser

    @poll.destroy
    redirect_to polls_url
  end

  def showvotes
    raise AccessError unless cuser.admin?
  end

  private

  def load_poll
    @poll = Poll.find params[:id]
  end
end
