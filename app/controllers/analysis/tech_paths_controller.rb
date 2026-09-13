# frozen_string_literal: true

module Analysis
  # /analysis/tech_paths -- the marine opening tech orders with the best win
  # rates, derived from raw `research_start` log lines by
  # MarineTechPathQuery. Alien chamber choices are exposed as a graph at
  # /analysis/alien_tech_tree.
  class TechPathsController < Analysis::BaseController
    def index
      @path_length_options = MarineTechPathQuery::PATH_LENGTH_OPTIONS
      @selected_path_length = MarineTechPathQuery.normalize_path_length(params[:path_length])
      @min_rounds_options = MarineTechPathQuery::MIN_ROUNDS_OPTIONS
      @selected_min_rounds = MarineTechPathQuery.normalize_min_rounds(params[:min_rounds])
      @result_limit_options = MarineTechPathQuery::RESULT_LIMIT_OPTIONS
      @selected_result_limit = MarineTechPathQuery.normalize_result_limit(params[:result_limit])
      @strategy_filter = MarineTechPathQuery.normalize_strategy_filter(params[:strategy_filter])

      query = MarineTechPathQuery.new(path_length: @selected_path_length, min_rounds: @selected_min_rounds,
                                      result_limit: @selected_result_limit, strategy_filter: @strategy_filter)
      @tech_paths = query.call
      @rounds_analysed = query.rounds_analysed
      @paths_found = query.paths_found
      @paths_above_minimum = query.paths_above_minimum

      render layout: 'full'
    end

    def tree
      query = MarineTechPathQuery.new(path_length: nil,
                                      min_rounds: MarineTechPathQuery::DEFAULT_MIN_ROUNDS,
                                      result_limit: nil)
      @tech_paths = query.call
      @rounds_analysed = query.rounds_analysed
      @tech_tree_team = 'Marine'
      @tech_tree_step = 'research option'

      render layout: 'full'
    end

    def alien_tree
      query = AlienTechPathQuery.new(path_length: nil,
                                     min_rounds: MarineTechPathQuery::DEFAULT_MIN_ROUNDS,
                                     result_limit: nil)
      @tech_paths = query.call
      @rounds_analysed = query.rounds_analysed
      @tech_tree_team = 'Alien'
      @tech_tree_step = 'chamber choice'

      render :tree, layout: 'full'
    end

    def requirements
      @min_rounds_options = MarineTechPathQuery::MIN_ROUNDS_OPTIONS
      @selected_min_rounds = MarineTechPathQuery.normalize_min_rounds(params[:min_rounds])
      query = MarineTechPathQuery.new(path_length: nil, min_rounds: 1, result_limit: nil)
      @tech_paths = query.call
      @rounds_analysed = query.rounds_analysed

      render layout: 'full'
    end
  end
end
