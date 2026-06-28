# frozen_string_literal: true

class BracketsController < ApplicationController
  before_action :load_bracket, only: %i[show edit update destroy]

  def show
    render layout: 'full'
  end

  def edit
    raise AccessError unless @bracket.can_update? cuser

    render layout: 'full'
  end

  def create
    @bracket = Bracket.new(Bracket.params(params, cuser))
    raise AccessError unless @bracket.can_create? cuser

    save_and_flash(@bracket, notice: :brackets_create) { @bracket.save }
    redirect_to edit_contest_path(@bracket.contest)
  end

  def update
    raise AccessError unless @bracket.can_update? cuser

    save_and_respond(@bracket, notice: :brackets_update,
                               location: edit_bracket_path(@bracket),
                               template: :edit, layout: 'full') do
      @bracket.update_with_cells(params, cuser)
    end
  end

  def destroy
    raise AccessError unless @bracket.can_destroy? cuser

    @bracket.destroy
    redirect_to edit_contest_path(@bracket.contest)
  end

  private

  def load_bracket
    @bracket = Bracket.find(params[:id])
  end
end
