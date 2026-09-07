# frozen_string_literal: true

# Win rate as a function of how long the round lasted, for the imported Round
# rows. Used by Analysis::RoundLengthsController#index.
#
# Two views of the same data:
# * `buckets` -- marine/alien win rates per round-length bucket, optionally
#   narrowed to a single map.
# * `maps` -- one row per map with its typical round length next to its win
#   rate, which is the "does this map play long or short, and does that
#   favour anyone" cross-section.
#
# The bucket edges deliberately mirror the pipeline's own `round_duration`
# export (minute buckets up to 20, then coarser ones) so the numbers here
# line up with what ensl_analysis reports. We compute them from `rounds`
# rather than importing that export because only the raw rows carry the map
# name, and the map breakdown is the whole point of this page.
class RoundLengthQuery
  MINUTE = 60

  # Upper edges in minutes; the final bucket is open-ended (60+).
  BUCKET_EDGES = ((1..20).to_a + [22, 24, 26, 28, 30, 35, 40, 45, 50, 55, 60]).freeze

  Bucket = Struct.new(:label, :start_minutes, :end_minutes, :rounds, :marine_wins, :alien_wins,
                      :marine_win_percentage, :alien_win_percentage, keyword_init: true)

  def self.call(map: nil)
    new(map: map).call
  end

  # Maps the untrusted `map` query param onto a map we actually have rounds
  # for, or nil for "every map". Case-insensitive, like the grouping below.
  def self.normalize_map(value)
    name = value.to_s.downcase.presence
    return nil unless name

    Round.where('LOWER(map_name) = ?', name).exists? ? name : nil
  end

  def initialize(map: nil)
    @map = map.to_s.downcase.presence
  end

  def call
    selected = @map ? rounds.select { |round| round[:map_name] == @map } : rounds

    {
      map: @map,
      map_options: map_options,
      buckets: buckets_for(selected),
      maps: map_rows,
      total_rounds: selected.size,
      marine_win_percentage: percentage(selected.count { |round| round[:marine_win] }, selected.size),
      median_seconds: median(selected.map { |round| round[:seconds] })
    }
  end

  private

  # Every finished round as a plain hash: only rounds that both ended and
  # recorded a winner can say anything about win rate by length.
  def rounds
    @rounds ||= Round.where.not(start_time: nil).where.not(end_time: nil).where.not(result: nil)
                     .pluck(:map_name, :start_time, :end_time, :result)
                     .filter_map do |map_name, start_time, end_time, result|
      seconds = (end_time - start_time).to_i
      next unless seconds >= 0

      # The logs spell the same map every which way (ns_veil, NS_VEiL, ...),
      # so casing is normalised away before anything is grouped by map.
      { map_name: map_name&.downcase, seconds: seconds, marine_win: result == Round::RESULT_MARINE_WIN }
    end
  end

  def buckets_for(subset)
    by_bucket = subset.group_by { |round| bucket_index(round[:seconds]) }

    bucket_bounds.each_with_index.map do |(start_minutes, end_minutes), index|
      in_bucket = by_bucket.fetch(index, [])
      marine_wins = in_bucket.count { |round| round[:marine_win] }
      Bucket.new(
        label: bucket_label(start_minutes, end_minutes),
        start_minutes: start_minutes, end_minutes: end_minutes,
        rounds: in_bucket.size, marine_wins: marine_wins, alien_wins: in_bucket.size - marine_wins,
        marine_win_percentage: percentage(marine_wins, in_bucket.size),
        alien_win_percentage: percentage(in_bucket.size - marine_wins, in_bucket.size)
      )
    end
  end

  # [[0, 1], [1, 2], ..., [55, 60], [60, nil]]
  def bucket_bounds
    @bucket_bounds ||= ([0] + BUCKET_EDGES).each_cons(2).to_a + [[BUCKET_EDGES.last, nil]]
  end

  def bucket_index(seconds)
    minutes = seconds / MINUTE
    BUCKET_EDGES.index { |edge| minutes < edge } || BUCKET_EDGES.size
  end

  def bucket_label(start_minutes, end_minutes)
    end_minutes ? "#{start_minutes}–#{end_minutes}" : "#{start_minutes}+"
  end

  # A handful of imported rounds have no map name (truncated logs); they still
  # count towards the length buckets, but there is no map row to put them in.
  def map_rows
    @map_rows ||= begin
      named = rounds.reject { |round| round[:map_name].blank? }
      rows = named.group_by { |round| round[:map_name] }.map do |map_name, in_map|
        marine_wins = in_map.count { |round| round[:marine_win] }
        {
          map_name: map_name,
          rounds: in_map.size,
          median_seconds: median(in_map.map { |round| round[:seconds] }),
          marine_win_percentage: percentage(marine_wins, in_map.size)
        }
      end
      rows.sort_by { |row| -row[:rounds] }
    end
  end

  def map_options
    map_rows.map { |row| [row[:map_name], row[:rounds]] }
  end

  def percentage(count, total)
    return nil if total.zero?

    count.fdiv(total) * 100
  end

  def median(values)
    return nil if values.empty?

    sorted = values.sort
    middle = sorted.size / 2
    sorted.size.odd? ? sorted[middle] : (sorted[middle - 1] + sorted[middle]).fdiv(2)
  end
end
