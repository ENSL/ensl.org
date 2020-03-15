class IssuesController < ApplicationController
  before_filter :get_issue, only: [:show, :edit, :update, :destroy]

  def index
    raise AccessError unless cuser and (cuser.admin? or cuser.moderator?)

    sort = case params['sort']
           when "title"  then "title"
           when "status" then "status"
           when "assigned" then "assigned_id"
           when "category" then "category_id"
           else "created_at DESC"
           end

    allowed = Issue::allowed_categories cuser
    qstring = 'category_id IN (?)'
    qstring += ' OR category_id IS NULL' if cuser.admin?

    @open = Issue.where(qstring, allowed).with_status(Issue::STATUS_OPEN).order(sort)
    @solved = Issue.where(qstring, allowed).with_status(Issue::STATUS_SOLVED).order(sort)
    @rejected = Issue.where(qstring, allowed).with_status(Issue::STATUS_REJECTED).order(sort)
  end

  def show
    raise AccessError unless @issue.can_show? cuser
    @issue.mark_as_read! for: cuser
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
      render :new
    end
  end

  def update
    raise AccessError unless @issue.can_update?(cuser, params[:issue])
    if @issue.update_attributes(params[:issue])
      flash[:notice] = t(:issues_update)
      redirect_to(@issue)
    else
      render :edit
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
