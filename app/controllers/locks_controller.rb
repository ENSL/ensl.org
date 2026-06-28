# frozen_string_literal: true

class LocksController < ApplicationController
  def create
    @lock = Lock.new(Lock.params(params, cuser))
    raise AccessError unless @lock.can_create? cuser

    save_and_flash(@lock, notice: :topics_locked) { @lock.save }
    redirect_to_back
  end

  def destroy
    @lock = Lock.find params[:id]
    raise AccessError unless @lock.can_destroy? cuser

    @lock.destroy
    redirect_to_back
  end
end
