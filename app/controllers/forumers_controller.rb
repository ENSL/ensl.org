# frozen_string_literal: true

class ForumersController < ApplicationController
  before_action :load_forumer, only: %i[update destroy]

  def create
    @forumer = Forumer.new(Forumer.params(params, cuser))
    raise AccessError unless @forumer.can_create? cuser

    save_and_flash(@forumer, notice: 'groups.added') { @forumer.save }
    redirect_to_back
  end

  def update
    raise AccessError unless @forumer.can_update? cuser

    save_and_flash(@forumer, notice: 'groups.acl.update') { @forumer.update(Forumer.params(params, cuser)) }
    redirect_to_back
  end

  def destroy
    raise AccessError unless @forumer.can_destroy? cuser

    @forumer.destroy
    redirect_to_back
  end

  private

  def load_forumer
    @forumer = Forumer.find(params[:id])
  end
end
