# frozen_string_literal: true

# Pivots the current imported `time_of_week` analysis snapshot into a
# day-of-week x hour-of-day activity grid for Analysis::ActivityController.
class RoundActivityQuery
  DAY_NAMES = %w[Monday Tuesday Wednesday Thursday Friday Saturday Sunday].freeze
  HOURS = (0..23).to_a.freeze

  Cell = Struct.new(:day_index, :hour, :rounds, :share, keyword_init: true)
  Day = Struct.new(:index, :name, :cells, :total, keyword_init: true)

  def self.call
    new.call
  end

  def call
    counts = tally
    busiest = counts.values.max || 0

    days = DAY_NAMES.each_with_index.map do |name, day_index|
      cells = HOURS.map do |hour|
        count = counts[[day_index, hour]]
        Cell.new(day_index: day_index, hour: hour, rounds: count,
                 share: busiest.zero? ? 0.0 : count.fdiv(busiest))
      end
      Day.new(index: day_index, name: name, cells: cells, total: cells.sum(&:rounds))
    end

    {
      days: days,
      hour_totals: HOURS.map { |hour| days.sum { |day| day.cells[hour].rounds } },
      total_rounds: counts.values.sum,
      busiest_cell: busiest_cell(counts, busiest)
    }
  end

  private

  def tally
    results.each_with_object(Hash.new(0)) do |result, memo|
      memo[[monday_first_index(result.steamid.to_i), result.milestone]] += result.value.to_i
    end
  end

  def results
    AnalysisResult.current_snapshot.where(model: 'time_of_week', metric: 'round_count')
                  .where.not(steamid: [AnalysisResult::NO_STEAMID, nil])
                  .where(milestone: HOURS)
  end

  # Exported day_of_week is Sunday-first (0..6); display is Monday-first.
  def monday_first_index(day_of_week)
    (day_of_week + 6) % 7
  end

  def busiest_cell(counts, busiest)
    return nil unless busiest.positive?

    day_index, hour = counts.key(busiest)
    { day_name: DAY_NAMES[day_index], hour: hour, count: busiest }
  end
end
