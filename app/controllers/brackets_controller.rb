# frozen_string_literal: true

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

    if @bracket.save
      flash[:notice] = t(:brackets_create)
    else
      flash[:error] = @bracket.errors.full_messages.to_sentence
    end

    redirect_to edit_contest_path(@bracket.contest)
  end

  def update
    raise AccessError unless @bracket.can_update? cuser

    # Handle cell updates - permit nested structure with custom field
    cell_params = params.permit(cell: {}, cell_custom: {})

    if @bracket.update(Bracket.params(params, cuser))
      @bracket.update_cells(cell_params[:cell] || {})
      @bracket.update_custom_text(cell_params[:cell_custom] || {})

      flash[:notice] = t(:brackets_update)
      redirect_to edit_bracket_path(@bracket)
    else
      flash.now[:error] = @bracket.errors.full_messages.to_sentence.presence || t(:error)
      render :edit, layout: 'full', status: :unprocessable_entity
    end
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
