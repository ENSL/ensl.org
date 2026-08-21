# frozen_string_literal: true

module Analysis
  # /analysis/pick_orders -- NS1 gather rankings from draft pick behaviour.
  # Includes pick-order stats plus a separate pick-order-only OpenSkill score.
  # Doesn't touch
  # AnalysisResult at all; built straight from gathers/gatherers.
  class PickOrdersController < Analysis::BaseController
    def index
      @min_games_options = PickOrderRankingQuery::MIN_GAMES_OPTIONS
      @selected_min_games = normalize_min_games_param
      @rankings = PickOrderRankingQuery.call(game: 'NS1', min_games: @selected_min_games)
      render layout: 'full'
    end

    private

    def normalize_min_games_param
      # Keep reading min_picks for old bookmarks; min_games is the new name.
      raw = params[:min_games] || params[:min_picks]
      value = Integer(raw, exception: false)
      return PickOrderRankingQuery::DEFAULT_MIN_GAMES unless value
      return PickOrderRankingQuery::DEFAULT_MIN_GAMES unless PickOrderRankingQuery::MIN_GAMES_OPTIONS.include?(value)

      value
    end
  end
end
