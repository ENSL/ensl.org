# frozen_string_literal: true

module Analysis
  class ActivityController < Analysis::BaseController
    def index
      activity = RoundActivityQuery.call
      @days = activity[:days]
      @hour_totals = activity[:hour_totals]
      @total_rounds = activity[:total_rounds]
      @busiest_cell = activity[:busiest_cell]

      render layout: 'full'
    end
  end
end
