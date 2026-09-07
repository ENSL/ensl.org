# frozen_string_literal: true

module Analysis
  # /analysis/round_lengths -- marine vs alien win rate as a function of how
  # long the round ran, either across every map or narrowed to one, plus a
  # per-map "how long does this map play" cross-section. See RoundLengthQuery.
  class RoundLengthsController < Analysis::BaseController
    def index
      @selected_map = RoundLengthQuery.normalize_map(params[:map])

      result = RoundLengthQuery.call(map: @selected_map)
      @buckets = result[:buckets]
      @maps = result[:maps]
      @map_options = result[:map_options]
      @total_rounds = result[:total_rounds]
      @marine_win_percentage = result[:marine_win_percentage]
      @median_seconds = result[:median_seconds]

      render layout: 'full'
    end
  end
end
