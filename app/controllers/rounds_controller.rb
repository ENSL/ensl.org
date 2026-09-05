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
    # "attacked" (a hit landing, logged per-shot/per-bite) dwarfs every other
    # event type -- often 5-10x the volume of everything else combined -- and
    # "player_acts" is just connection bookkeeping (connected/validated/entered
    # the game) -- neither adds narrative value, so both are excluded to keep
    # the timeline legible and the page light.
    log_lines = @round.log_lines.where.not(event_type: %w[attacked player_acts])
    # Pre-round setup (team picks, connects) can predate round.start_time --
    # the timeline only cares about what happened during the round itself.
    log_lines = log_lines.where(created_at: @round.start_time..) if @round.start_time
    @log_lines = log_lines.order(:created_at, :id).to_a
  end
end
