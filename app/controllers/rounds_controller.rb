# frozen_string_literal: true

# frozen_string_literal: true

# WIP: round/log data is now imported from the ensl_analysis Python pipeline
# (see RoundBatchImportService) instead of parsed in Rails. This controller
# and its views haven't been reworked for the new Round/Rounder schema yet --
# kept minimal (just enough to boot) rather than wired up for real display.
class RoundsController < ApplicationController
  def index
    @filters = round_filters
    @maps = Round.where.not(map_name: [nil, '']).distinct.order(:map_name).pluck(:map_name)
    @servers = Round.where.not(server_name: [nil, '']).distinct.order(:server_name).pluck(:server_name)
    scope = Round.filtered(@filters)
    if @filters[:steamid].present? || @filters[:username].present?
      scope = scope.left_joins(:rounders)
                   .joins("LEFT JOIN users ON users.steamid = REPLACE(rounders.steamid, 'STEAM_', '')")
    end
    scope = scope.joins('LEFT JOIN log_lines ON log_lines.round_id = rounds.id') if @filters[:nickname].present?
    @rounds = scope.preload(:rounders).order(start_time: :asc, id: :asc).paginate(page: params[:page], per_page: 50)
    render layout: 'full'
  end

  def calendar
    @year = params.fetch(:year, Time.zone.today.year).to_i.clamp(2000, Time.zone.today.year + 1)
    @round_counts = Round.where(start_time: Date.new(@year, 1, 1)...Date.new(@year + 1, 1, 1))
                         .group('DATE(start_time)').count
    render layout: 'full'
  end

  def statistics
    monthly_counts = Round.where.not(start_time: nil)
                          .group(Arel.sql('YEAR(start_time)'), Arel.sql('MONTH(start_time)')).count
    @total_rounds = monthly_counts.values.sum
    @months = monthly_buckets(monthly_counts)
    @years = @months.group_by { |month| month[:date].year }
                    .map { |year, months| { year: year, count: months.sum { |month| month[:count] } } }
                    .sort_by { |year| year[:year] }
    @quarters = @months.group_by { |month| [month[:date].year, ((month[:date].month - 1) / 3) + 1] }
                       .map do |(year, quarter), months|
                         { year: year, quarter: quarter, count: months.sum { |month| month[:count] } }
                       end
                       .sort_by { |quarter| [quarter[:year], quarter[:quarter]] }
    @peak_monthly_count = @months.map { |month| month[:count] }.max || 0
    render layout: 'full'
  end

  def show
    @round = Round.find(params[:id])
    @previous_round = Round.where('start_time < ? OR (start_time = ? AND id < ?)', @round.start_time, @round.start_time,
                                  @round.id).order(start_time: :desc, id: :desc).first
    @next_round = Round.where('start_time > ? OR (start_time = ? AND id > ?)', @round.start_time, @round.start_time,
                              @round.id).order(start_time: :asc, id: :asc).first
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
    render layout: 'full'
  end

  private

  def round_filters
    params.permit(:username, :nickname, :steamid, :map, :server, :result, :length, :from, :to)
  end

  def monthly_buckets(monthly_counts)
    return [] if monthly_counts.empty?

    first_year, first_month = monthly_counts.keys.min
    last_year, last_month = monthly_counts.keys.max
    first_date = Date.new(first_year, first_month, 1)
    last_date = Date.new(last_year, last_month, 1)

    (first_date..last_date).select { |date| date.day == 1 }.map do |date|
      { date: date, count: monthly_counts.fetch([date.year, date.month], 0) }
    end
  end
end
