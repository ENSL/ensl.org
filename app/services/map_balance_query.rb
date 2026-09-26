# frozen_string_literal: true

# Pivots the current map_balance cells into one hash per map. Used by
# Analysis::MapsController#index.
class MapBalanceQuery
  METRICS = %w[marine_wins alien_wins total_games marine_win_percentage alien_win_percentage].freeze

  def self.call
    new.call
  end

  # Returns an array of hashes: { map_name:, marine_wins:, alien_wins:,
  # total_games:, marine_win_percentage:, alien_win_percentage: }, sorted by
  # marine win percentage descending, with missing percentages last. Maps with no games
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
    rows.sort_by do |row|
      [row[:marine_win_percentage].nil? ? 1 : 0, -row[:marine_win_percentage].to_f, -row[:total_games]]
    end
  end

  private

  def relevant_results
    AnalysisResult.current_snapshot
                  .where(model: 'map_balance', field: ['map_name'] + METRICS)
  end

  def metrics_by_map
    AnalysisResult.rows_from(relevant_results).each_with_object({}) do |row, maps|
      map_name = row['map_name'].presence
      next unless map_name

      maps[map_name] = row.slice(*METRICS)
    end
  end
end
