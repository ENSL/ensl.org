# frozen_string_literal: true

module Analysis
  class AlienStrategiesController < Analysis::BaseController
    def index
      @report = AlienStrategyQuery.from_params(params).report
      render layout: 'full'
    end
  end
end
