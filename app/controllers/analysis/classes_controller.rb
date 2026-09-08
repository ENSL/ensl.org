# frozen_string_literal: true

module Analysis
  # /analysis/classes -- per-player NS1 class performance from the newest
  # historical analysis batch, aggregated independently of maps and teams.
  class ClassesController < Analysis::BaseController
    def index
      @class_names = ClassPerformanceQuery.class_names
      @selected_class_name = params[:class_name].presence if @class_names.include?(params[:class_name])
      @min_games_options = ClassPerformanceQuery::MIN_GAMES_OPTIONS
      @selected_min_games = normalize_min_games_param
      @performances = ClassPerformanceQuery.call(class_name: @selected_class_name, min_games: @selected_min_games)
      render layout: 'full'
    end

    private

    def normalize_min_games_param
      value = Integer(params[:min_games], exception: false)
      return ClassPerformanceQuery::DEFAULT_MIN_GAMES unless value
      return ClassPerformanceQuery::DEFAULT_MIN_GAMES unless ClassPerformanceQuery::MIN_GAMES_OPTIONS.include?(value)

      value
    end
  end
end
