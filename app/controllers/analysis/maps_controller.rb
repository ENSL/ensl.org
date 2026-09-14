# frozen_string_literal: true

module Analysis
  # /analysis/maps -- one row per map: current win-rate snapshot (marine vs
  # alien) pivoted out of AnalysisResult by MapBalanceQuery. Read-only, no
  # params, same shape as Analysis::UsersController.
  class MapsController < Analysis::BaseController
    def index
      @map_balances = MapBalanceQuery.call
      @rounds_analysed = @map_balances.sum { |balance| balance[:total_games].to_i }
      render layout: 'full'
    end
  end
end
