# frozen_string_literal: true

# frozen_string_literal: true

# WIP: round/log data is now imported from the ensl_analysis Python pipeline
# (see RoundBatchImportService) instead of parsed in Rails. This controller
# and its views haven't been reworked for the new Round/Rounder schema yet --
# kept minimal (just enough to boot) rather than wired up for real display.
class RoundsController < ApplicationController
  helper RoundsHelper

  def index
    archive = RoundArchiveQuery.call(filters: round_filters, page: params[:page])
    @filters, @maps, @servers, @rounds = archive.to_a
    render layout: 'full'
  end

  def calendar
    calendar = RoundCalendarQuery.call(year: params.fetch(:year, Time.zone.today.year))
    @year = calendar.year
    @round_counts = calendar.round_counts
    render layout: 'full'
  end

  def statistics
    statistics = RoundStatisticsQuery.call
    @total_rounds = statistics[:total_rounds]
    @months = statistics[:months]
    @years = statistics[:years]
    @quarters = statistics[:quarters]
    @peak_monthly_count = statistics[:peak_monthly_count]
    render layout: 'full'
  end

  def show
    @round = Round.find(params[:id])
    @previous_round = @round.previous
    @next_round = @round.next
    @log_lines = @round.timeline_log_lines.to_a
    render layout: 'full'
  end

  private

  def round_filters
    params.permit(:username, :nickname, :steamid, :map, :server, :result, :length, :from, :to)
  end
end
