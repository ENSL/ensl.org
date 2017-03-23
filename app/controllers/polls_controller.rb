class PollsController < ApplicationController
  before_filter :get_poll, except: [:index, :new, :create]

  def index
    @polls = Poll.all
  end

  def show
  end

  def new
    @poll = Poll.new
    @poll.options.build
    raise AccessError unless @poll.can_create? cuser
  end

  def edit
    raise AccessError unless @poll.can_update? cuser
  end

  def create
    @poll = Poll.new params[:poll]
    @poll.user = cuser
    raise AccessError unless @poll.can_create? cuser

    if @poll.save
      flash[:notice] = t(:polls_create)
      redirect_to @poll
    else
      render :new
    end
  end

  def update
    raise AccessError unless @poll.can_update? cuser

    if @poll.update_attributes params[:poll]
      flash[:notice] = t(:polls_update)
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

  def get_poll
    @poll = Poll.find params[:id]
  end
end
