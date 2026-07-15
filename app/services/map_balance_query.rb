# frozen_string_literal: true

# Pivots the current map_balance snapshot of AnalysisResult rows -- one row
# per (map_name, metric) -- into one hash per map. Used by
# Analysis::MapsController#index. Unlike PlayerRankingQuery this reads from
# the overwritable CURRENT_SNAPSHOT_BATCH_ID scope (see AnalysisResult),
# since map balance is a single upserted-in-place snapshot, not per-batch
# history. `steamid` is reused as the generic subject column here and holds
# the map name (see AnalysisBatchImportService#read_map_balance_rows).
class MapBalanceQuery
  METRICS = %w[marine_wins alien_wins total_games marine_win_percentage alien_win_percentage].freeze

  def self.call
    new.call
  end

  # Returns an array of hashes: { map_name:, marine_wins:, alien_wins:,
  # total_games:, marine_win_percentage:, alien_win_percentage: }, sorted by
  # total_games descending (most-played maps first). Maps with no games
  # recorded are skipped.
  def call
    rows = metrics_by_map.filter_map do |map_name, metrics|
      total_games = metrics['total_games']
      next unless total_games&.positive?

      {
        map_name: map_name,
        marine_wins: metrics['marine_wins'],
        alien_wins: metrics['alien_wins'],
        total_games: total_games,
        marine_win_percentage: metrics['marine_win_percentage'],
        alien_win_percentage: metrics['alien_win_percentage']
      }
    end
    rows.sort_by { |row| -row[:total_games] }
  end

  private

  def relevant_results
    AnalysisResult.current_snapshot
                  .where(model: 'map_balance', metric: METRICS)
                  .where.not(steamid: [AnalysisResult::NO_STEAMID, nil])
  end

  def metrics_by_map
    relevant_results.each_with_object(Hash.new { |h, k| h[k] = {} }) do |result, memo|
      memo[result.steamid][result.metric] = result.value
    end
  end
end
