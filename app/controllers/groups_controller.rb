class GroupsController < ApplicationController
  before_filter :get_group, :except => [:index, :new, :create]

  def index
    @groups = Group.all
  end

  def show
  end

  def new
    @group = Group.new
    raise AccessError unless @group.can_create? cuser
  end

  def edit
    @group.users.all
    raise AccessError unless @group.can_update? cuser
  end

  def create
    @group = Group.new params[:group]
    @group.founder = cuser
    raise AccessError unless @group.can_create? cuser
    if @group.save
      flash[:notice] = t(:groups_create)
      redirect_to @group
    else
      render :action => "new"
    end
  end

  def update
    raise AccessError unless @group.can_update? cuser
    if @group.update_attributes params[:group]
      flash[:notice] = t(:groups_update)
      redirect_to @group
    else
      render :action => "edit"
    end
  end

  def destroy
    raise AccessError unless @group.can_destroy? cuser
    @group.destroy
    redirect_to groups_url
  end

  def addUser
    @user = User.first :conditions => {:username => params[:username]}
    raise AccessError unless @group.can_update? cuser
    raise Error, t(:duplicate_user) if @group.users.include? @user

    @group.users << @user if @user
    redirect_to edit_group_url(@group, :groupTab => "groupTabMembers")
  end

  def delUser
    @user = User.find params[:id2]
    raise AccessError unless @group.can_update? cuser

    @group.users.delete @user
    redirect_to edit_group_url(@group, :groupTab => "groupTabMembers")
  end

  private

  def get_group
    @group = Group.find params[:id]
  end
end
