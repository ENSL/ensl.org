class GroupersController < ApplicationController
  def create
    @grouper = Grouper.new(Grouper.params(params, cuser))
    raise AccessError unless @grouper.can_create? cuser

    if @grouper.save
      flash[:notice] = t(:groups_user_add)
      redirect_to edit_group_url(@grouper.group, anchor: 'members')
    else
      @group = @grouper.group
      @new_grouper = @grouper
      @group_tab = 'members'
      respond_with_validation_errors(@grouper, template: 'groups/edit')
    end
  end

  def update
    @grouper = Grouper.find params[:id]
    raise AccessError unless @grouper.can_update? cuser

    if @grouper.update(Grouper.params(params, cuser))
      flash[:notice] = t(:groups_user_update)
      redirect_to edit_group_url(@grouper.group, anchor: 'members')
    else
      @group = @grouper.group
      @new_grouper = Grouper.new(group: @group)
      @group_tab = 'members'
      respond_with_validation_errors(@grouper, template: 'groups/edit')
    end
  end

  def destroy
    @grouper = Grouper.find params[:id]
    raise AccessError unless @grouper.can_destroy? cuser

    @grouper.destroy
    flash[:notice] = t(:groups_user_remove)
    redirect_to edit_group_url(@grouper.group, anchor: 'members')
  end
end
