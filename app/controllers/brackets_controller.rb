class BracketsController < ApplicationController
  before_action :get_bracket, only: [:show, :edit, :update, :destroy]

  def edit
    raise AccessError unless @bracket.can_update? cuser
    render layout: 'full'
  end

  def create
    @bracket = Bracket.new Bracket.params(params, cuser)
    raise AccessError unless @bracket.can_create? cuser

    if @bracket.save
      flash[:notice] = t(:brackets_create)
    end

    redirect_to edit_contest_path(@bracket.contest)
  end

  def update
    raise AccessError unless @bracket.can_update? cuser

    if @bracket.update_attributes(Bracket.params(params, cuser)) and @bracket.update_cells(params.permit(:cell)[:cell])
      flash[:notice] = t(:brackets_update)
    end

    render :edit
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
