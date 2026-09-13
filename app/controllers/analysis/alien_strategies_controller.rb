# frozen_string_literal: true

module Analysis
  class AlienStrategiesController < Analysis::BaseController
    def index
      @action_limit_options = AlienStrategyQuery::ACTION_LIMIT_OPTIONS
      @selected_action_limit = AlienStrategyQuery.normalize_action_limit(params[:action_limit])
      @min_rounds_options = AlienStrategyQuery::MIN_ROUNDS_OPTIONS
      @selected_min_rounds = AlienStrategyQuery.normalize_min_rounds(params[:min_rounds])
      @result_limit_options = AlienStrategyQuery::RESULT_LIMIT_OPTIONS
      @selected_result_limit = AlienStrategyQuery.normalize_result_limit(params[:result_limit])
      @result_view_options = AlienStrategyQuery::RESULT_VIEW_OPTIONS
      @selected_result_view = AlienStrategyQuery.normalize_result_view(params[:result_view])
      @min_median_win_time_options = AlienStrategyQuery::MIN_MEDIAN_WIN_TIME_OPTIONS
      @selected_min_median_win_time = AlienStrategyQuery.normalize_min_median_win_time(params[:min_median_win_time])
      @strategy_filter = AlienStrategyQuery.normalize_strategy_filter(params[:strategy_filter])
      @coalesce_chambers = AlienStrategyQuery.normalize_coalesce_chambers(params[:coalesce_chambers])

      query = AlienStrategyQuery.new(action_limit: @selected_action_limit, min_rounds: @selected_min_rounds,
                                     result_limit: @selected_result_limit, result_view: @selected_result_view,
                                     min_median_win_time: @selected_min_median_win_time,
                                     strategy_filter: @strategy_filter, coalesce_chambers: @coalesce_chambers)
      @strategies = query.call
      @batch_id = query.latest_batch_id
      @rounds_analysed = query.rounds_analysed
      @strategies_found = query.strategies_found
      @strategies_above_minimum = query.strategies_above_minimum
      @results_above_filters = query.results_above_filters

      render layout: 'full'
    end
  end
end
