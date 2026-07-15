# frozen_string_literal: true

module Analysis
  # /analysis/users -- one row per player: current skill ratings (per model)
  # plus win/loss stats, pivoted out of AnalysisResult by PlayerRankingQuery.
  # Sorting happens entirely client-side (see AnalysisHelper#sortable_table),
  # so this stays a plain index with no params/pagination to worry about.
  class UsersController < Analysis::BaseController
    def index
      @min_games_options = PlayerRankingQuery::MIN_GAMES_OPTIONS
      @selected_min_games = normalize_min_games_param
      @rankings = PlayerRankingQuery.call(min_games: @selected_min_games)
      render layout: 'full'
    end

    private

    def normalize_min_games_param
      value = Integer(params[:min_games], exception: false)
      return PlayerRankingQuery::DEFAULT_MIN_GAMES unless value
      return PlayerRankingQuery::DEFAULT_MIN_GAMES unless PlayerRankingQuery::MIN_GAMES_OPTIONS.include?(value)

      value
    end
  end
end
