# frozen_string_literal: true

module Analysis
  # /analysis/maps -- one row per map: current win-rate snapshot (marine vs
  # alien) pivoted out of AnalysisResult by MapBalanceQuery. Read-only, no
  # params, same shape as Analysis::UsersController.
  class MapsController < Analysis::BaseController
    def index
      @map_balances = MapBalanceQuery.call
      render layout: 'full'
    end
  end
end
