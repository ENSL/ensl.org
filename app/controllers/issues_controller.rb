class IssuesController < ApplicationController
  before_filter :get_issue, :only => [:show, :edit, :update, :destroy]

  def index
    raise AccessError unless cuser and cuser.admin?

    sort = case params['sort']
           when "title"  then "title"
           when "status" then "status"
           when "assigned" then "assigned_id"
           when "category" then "category_id"
           else "created_at DESC"
           end

    @open = Issue.with_status(Issue::STATUS_OPEN).all :order => sort
    @solved = Issue.with_status(Issue::STATUS_SOLVED).all :order => sort
    @rejected = Issue.with_status(Issue::STATUS_REJECTED).all :order => sort
  end

  def show
    raise AccessError unless @issue.can_show? cuser
    @issue.read_by! cuser
  end

  def new
    @issue = Issue.new
    raise AccessError unless @issue.can_create? cuser
  end

  def edit
    raise AccessError unless @issue.can_update? cuser
  end

  def create
    @issue = Issue.new(params[:issue])
    @issue.author = cuser if cuser
    raise AccessError unless @issue.can_create? cuser

    if @issue.save
      flash[:notice] = t(:issues_create)
      if cuser
        redirect_to(@issue)
      else
        redirect_to_home
      end
    else
      render :action => "new"
    end
  end

  def update
    raise AccessError unless @issue.can_update? cuser
    if @issue.update_attributes(params[:issue])
      flash[:notice] = t(:issues_update)
      redirect_to(@issue)
    else
      render :action => "edit"
    end
  end

  def destroy
    raise AccessError unless @issue.can_destroy? cuser
    @issue.destroy
    redirect_to(issues_url)
  end

  private

  def get_issue
    @issue = Issue.find params[:id]
  end
end
