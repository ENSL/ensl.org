class BracketsController < ApplicationController
  before_action :get_bracket, only: %i[show edit update destroy]

  def show
    render layout: 'full'
  end

  def edit
    raise AccessError unless @bracket.can_update? cuser

    render layout: 'full'
  end

  def create
    @bracket = Bracket.new Bracket.params(params, cuser)
    raise AccessError unless @bracket.can_create? cuser

    flash[:notice] = t(:brackets_create) if @bracket.save

    redirect_to edit_contest_path(@bracket.contest)
  end

  def update
    raise AccessError unless @bracket.can_update? cuser

    @bracket.update(Bracket.params(params, cuser))

    # Handle cell updates - permit nested structure with custom field
    cell_params = params.permit(cell: {}, cell_custom: {})
    @bracket.update_cells(cell_params[:cell] || {})
    @bracket.update_custom_text(cell_params[:cell_custom] || {})

    flash[:notice] = t(:brackets_update)

    render :edit, layout: 'full'
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
