class LocksController < ApplicationController
  def create
    @lock = Lock.new params[:lock]
    raise AccessError unless @lock.can_create? cuser

    if @lock.save
      flash[:notice] = t(:topics_locked)
    else
      flash[:error] = @lock.errors.full_messages.to_s
    end

    redirect_to_back
  end

  def destroy
    @lock = Lock.find params[:id]
    raise AccessError unless @lock.can_destroy? cuser

    @lock.destroy
    redirect_to_back
  end
end
