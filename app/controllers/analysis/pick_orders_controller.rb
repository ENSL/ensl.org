# frozen_string_literal: true

module Analysis
  # /analysis/pick_orders -- NS1 gather rankings from draft pick behaviour.
  # Includes pick-order stats plus a separate pick-order-only OpenSkill score.
  # Doesn't touch
  # AnalysisResult at all; built straight from gathers/gatherers.
  class PickOrdersController < Analysis::BaseController
    def index
      @report = PickOrderRankingQuery.from_params(params).report
      render layout: 'full'
    end
  end
end
