# frozen_string_literal: true

module Analysis
  # /analysis/pick_orders -- NS1 players ranked by average draft pick order
  # (how fast they usually get picked by captains). Doesn't touch
  # AnalysisResult at all; built straight from gathers/gatherers.
  class PickOrdersController < Analysis::BaseController
    def index
      @min_picks_options = PickOrderRankingQuery::MIN_PICKS_OPTIONS
      @selected_min_picks = normalize_min_picks_param
      @rankings = PickOrderRankingQuery.call(game: 'NS1', min_picks: @selected_min_picks)
      render layout: 'full'
    end

    private

    def normalize_min_picks_param
      value = Integer(params[:min_picks], exception: false)
      return PickOrderRankingQuery::DEFAULT_MIN_PICKS unless value
      return PickOrderRankingQuery::DEFAULT_MIN_PICKS unless PickOrderRankingQuery::MIN_PICKS_OPTIONS.include?(value)

      value
    end
  end
end
