# frozen_string_literal: true

module Analysis
  class CountriesController < Analysis::BaseController
    def index
      @report = CountryStatisticsQuery.call
      render layout: 'full'
    end
  end
end
