# frozen_string_literal: true

# Aggregates imported rounds into the time-series data shown in the archive
# statistics view.
class RoundStatisticsQuery
  def self.call
    new.call
  end

  def call
    months = monthly_buckets(monthly_counts)

    {
      total_rounds: months.sum { |month| month[:count] },
      months: months,
      years: year_summaries(months),
      quarters: quarter_summaries(months),
      peak_monthly_count: months.map { |month| month[:count] }.max || 0
    }
  end

  private

  def monthly_counts
    Round.where.not(start_time: nil)
         .group(Arel.sql('YEAR(start_time)'), Arel.sql('MONTH(start_time)')).count
  end

  def monthly_buckets(counts)
    return [] if counts.empty?

    first_year, first_month = counts.keys.min
    last_year, last_month = counts.keys.max
    first_date = Date.new(first_year, first_month, 1)
    last_date = Date.new(last_year, last_month, 1)

    (first_date..last_date).select { |date| date.day == 1 }.map do |date|
      { date: date, count: counts.fetch([date.year, date.month], 0) }
    end
  end

  def year_summaries(months)
    years = months.group_by { |month| month[:date].year }
    summaries = years.map { |year, entries| { year: year, count: entries.sum { |month| month[:count] } } }
    summaries.sort_by { |year| year[:year] }
  end

  def quarter_summaries(months)
    quarters = months.group_by { |month| [month[:date].year, ((month[:date].month - 1) / 3) + 1] }
    summaries = quarters.map do |(year, quarter), entries|
      { year: year, quarter: quarter, count: entries.sum { |month| month[:count] } }
    end
    summaries.sort_by { |quarter| [quarter[:year], quarter[:quarter]] }
  end
end
