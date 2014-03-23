class BracketsController < ApplicationController
  before_filter :get_bracket, :only => [:show, :edit, :update, :destroy]

  def edit
    raise AccessError unless @bracket.can_update? cuser
  end

  def create
    @bracket = Bracket.new params[:bracket]
    raise AccessError unless @bracket.can_create? cuser

    if @bracket.save
      flash[:notice] = t(:brackets_create)
    end

    redirect_to edit_contest_path(@bracket.contest)
  end

  def update
    raise AccessError unless @bracket.can_update? cuser

    if @bracket.update_attributes params[:bracket] and @bracket.update_cells(params[:cell])
      flash[:notice] = t(:brackets_update)
    end

    render :action => "edit"
  end

  def destroy
    raise AccessError unless @bracket.can_destroy? cuser
    @bracket.destroy
    redirect_to edit_contest_path(@bracket.contest)
  end

  private

  def get_bracket
    @bracket = Bracket.find(params[:id])
  end
end
