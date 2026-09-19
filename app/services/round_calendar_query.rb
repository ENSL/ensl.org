# frozen_string_literal: true

# Supplies the archive calendar with a supported year and its daily round
# counts.
class RoundCalendarQuery
  Result = Struct.new(:year, :round_counts, keyword_init: true)

  def self.call(year:)
    new(year: year).call
  end

  def initialize(year:)
    @year = year
  end

  def call
    Result.new(year: selected_year, round_counts: Round.counts_by_day_in(selected_year))
  end

  private

  def selected_year
    @selected_year ||= @year.to_i.clamp(2000, Time.zone.today.year + 1)
  end
end
