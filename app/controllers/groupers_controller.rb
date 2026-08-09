# frozen_string_literal: true

class GroupersController < ApplicationController
  def create
    @grouper = Grouper.new(Grouper.params(params, cuser))
    raise AccessError unless @grouper.can_create? cuser

    if @grouper.save
      flash[:notice] = t('groups.users.add')
      redirect_to edit_group_url(@grouper.group, anchor: 'members')
    else
      prepare_group_edit(@grouper, new_grouper: @grouper)
      respond_with_validation_errors(@grouper, template: 'groups/edit')
    end
  end

  def update
    @grouper = Grouper.find params[:id]
    raise AccessError unless @grouper.can_update? cuser

    if @grouper.update(Grouper.params(params, cuser))
      flash[:notice] = t('groups.users.update')
      redirect_to edit_group_url(@grouper.group, anchor: 'members')
    else
      prepare_group_edit(@grouper)
      respond_with_validation_errors(@grouper, template: 'groups/edit')
    end
  end

  def destroy
    @grouper = Grouper.find params[:id]
    raise AccessError unless @grouper.can_destroy? cuser

    @grouper.destroy
    flash[:notice] = t('groups.users.remove')
    redirect_to edit_group_url(@grouper.group, anchor: 'members')
  end

  private

  def prepare_group_edit(grouper, new_grouper: Grouper.new(group: grouper.group))
    @group = grouper.group
    @new_grouper = new_grouper
    @group_tab = 'members'
  end
end
