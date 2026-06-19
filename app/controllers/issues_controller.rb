# frozen_string_literal: true

class IssuesController < ApplicationController
  before_action :require_index_access!, only: :index
  before_action :get_issue, only: %i[show edit update destroy]

  def index
    allowed = Issue.allowed_categories cuser
    qstring = 'category_id IN (?)'
    qstring += ' OR category_id IS NULL' if cuser.admin?

    @open = Issue.where(qstring, allowed).with_status(Issue::STATUS_OPEN).order(issue_sort)
    @solved = Issue.where(qstring, allowed).with_status(Issue::STATUS_SOLVED).order(issue_sort)
    @rejected = Issue.where(qstring, allowed).with_status(Issue::STATUS_REJECTED).order(issue_sort)
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
    @issue = Issue.new(Issue.params(params, cuser))
    @issue.author = cuser if cuser
    raise AccessError unless @issue.can_create? cuser

    # verify reCAPTCHA for anonymous users
    if cuser.nil? && !verify_recaptcha(model: @issue)
      render :new
      return
    end

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

    if @issue.update(Issue.params(params, cuser))
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

  def require_index_access!
    raise AccessError unless cuser&.admin? || cuser&.moderator?
  end

  def get_issue
    @issue = Issue.find params[:id]
  end

  def issue_sort
    case params[:sort]
    when 'title' then 'title'
    when 'status' then 'status'
    when 'assigned' then 'assigned_id'
    when 'category' then 'category_id'
    else 'created_at DESC'
    end
  end
end
