class GroupersController < ApplicationController
  def create
    @grouper = Grouper.new(Grouper.params(params, cuser))
    raise AccessError unless @grouper.can_create? cuser

    if @grouper.save
      flash[:notice] = t(:groups_user_add)
    else
      flash[:error] = @grouper.errors.full_messages.to_s
    end

    redirect_to_back
  end

  def update
    @grouper = Grouper.find params[:id]
    raise AccessError unless @grouper.can_update? cuser

    if @grouper.update_attributes(Grouper.params(params, cuser))
      flash[:notice] = t(:groups_user_update)
    else
      flash[:error] = @grouper.errors.full_messages.to_s
    end

    redirect_to_back
  end

  def destroy
    @grouper = Grouper.find params[:id]
    raise AccessError unless @grouper.can_destroy? cuser

    @grouper.destroy
    redirect_to_back
  end
end
