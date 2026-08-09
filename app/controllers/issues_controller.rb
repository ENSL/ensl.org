# frozen_string_literal: true

class IssuesController < ApplicationController
  before_action :require_index_access!, only: :index
  before_action :load_issue, only: %i[show edit update destroy]

  def index
    scope = Issue.visible_to(cuser).order(Issue.sort_column(params[:sort]))
    @open = scope.with_status(Issue::STATUS_OPEN)
    @solved = scope.with_status(Issue::STATUS_SOLVED)
    @rejected = scope.with_status(Issue::STATUS_REJECTED)
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
      flash[:notice] = flash_action_message(:create, @issue)
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
      flash[:notice] = flash_action_message(:update, @issue)
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

  def load_issue
    @issue = Issue.find params[:id]
  end
end
