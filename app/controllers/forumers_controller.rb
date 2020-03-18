class ForumersController < ApplicationController
  def create
    @forumer = Forumer.new(Forumer.params(params, cuser))
    raise AccessError unless @forumer.can_create? cuser

    if @forumer.save
      flash[:notice] = t(:groups_added)
    else
      flash[:error] = @forumer.errors.full_messages.to_s
    end

    redirect_to_back
  end

  def update
    @forumer = Forumer.find params[:id]
    raise AccessError unless @forumer.can_update? cuser

    if @forumer.update_attributes(Forumer.params(params, cuser))
      flash[:notice] = t(:groups_acl_update)
    else
      flash[:error] = @forumer.errors.full_messages.to_s
    end

    redirect_to_back
  end

  def destroy
    @forumer = Forumer.find params[:id]
    raise AccessError unless @forumer.can_destroy? cuser

    @forumer.destroy
    redirect_to_back
  end
end
