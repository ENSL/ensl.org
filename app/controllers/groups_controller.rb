# frozen_string_literal: true

class GroupsController < ApplicationController
  before_action :get_group, except: %i[index new create]

  def index
    @groups = Group.all
  end

  def show; end

  def new
    @group = Group.new
    raise AccessError unless @group.can_create? cuser
  end

  def edit
    raise AccessError unless @group.can_update? cuser

    prepare_edit_dependencies
  end

  def create
    @group = Group.new(Group.params(params, cuser))
    @group.founder = cuser
    raise AccessError unless @group.can_create? cuser

    if @group.save
      flash[:notice] = t(:groups_create)
      redirect_to @group
    else
      respond_with_validation_errors(@group, template: :new)
    end
  end

  def update
    raise AccessError unless @group.can_update? cuser

    if @group.update(Group.params(params, cuser))
      flash[:notice] = t(:groups_update)
      redirect_to @group
    else
      prepare_edit_dependencies
      respond_with_validation_errors(@group, template: :edit)
    end
  end

  def destroy
    raise AccessError unless @group.can_destroy? cuser

    @group.destroy
    redirect_to groups_url
  end

  private

  def prepare_edit_dependencies
    @group.users.load
    @new_grouper = Grouper.new(group: @group)
  end

  def get_group
    @group = Group.find params[:id]
  end
end
