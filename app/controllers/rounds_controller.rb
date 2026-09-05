# frozen_string_literal: true

# frozen_string_literal: true

# WIP: round/log data is now imported from the ensl_analysis Python pipeline
# (see RoundBatchImportService) instead of parsed in Rails. This controller
# and its views haven't been reworked for the new Round/Rounder schema yet --
# kept minimal (just enough to boot) rather than wired up for real display.
class RoundsController < ApplicationController
  def index
    @rounds = Round.order(start_time: :desc).paginate(page: params[:page], per_page: 30)
  end

  def show
    @round = Round.find(params[:id])
  end
end

