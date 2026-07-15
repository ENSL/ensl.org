# frozen_string_literal: true

module Analysis
  # /analysis/users -- one row per player: current skill ratings (per model)
  # plus win/loss stats, pivoted out of AnalysisResult by PlayerRankingQuery.
  # Sorting happens entirely client-side (see AnalysisHelper#sortable_table),
  # so this stays a plain index with no params/pagination to worry about.
  class UsersController < Analysis::BaseController
    def index
      @rankings = PlayerRankingQuery.call
      render layout: 'full'
    end
  end
end
