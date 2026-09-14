# frozen_string_literal: true

module Analysis
  # /analysis/tech_paths -- the marine opening tech orders with the best win
  # rates, derived from raw `research_start` log lines by
  # MarineTechPathQuery. Alien chamber choices are exposed as a graph at
  # /analysis/alien_tech_tree.
  class TechPathsController < Analysis::BaseController
    MARINE_GRAPH_MIN_ROUNDS_OPTIONS = [5, 10, 25, 50].freeze
    ALIEN_GRAPH_MIN_ROUNDS_OPTIONS = [1, 5, 10, 25, 50].freeze

    def index
      @path_length_options = MarineTechPathQuery::PATH_LENGTH_OPTIONS
      @selected_path_length = MarineTechPathQuery.normalize_path_length(params[:path_length])
      @min_rounds_options = MarineTechPathQuery::MIN_ROUNDS_OPTIONS
      @selected_min_rounds = MarineTechPathQuery.normalize_min_rounds(params[:min_rounds])
      @result_limit_options = MarineTechPathQuery::RESULT_LIMIT_OPTIONS
      @selected_result_limit = MarineTechPathQuery.normalize_result_limit(params[:result_limit])
      @strategy_filter = MarineTechPathQuery.normalize_strategy_filter(params[:strategy_filter])
      @individual_techs = @selected_path_length == MarineTechPathQuery::INDIVIDUAL_TECHS_PATH_LENGTH

      query = MarineTechPathQuery.new(path_length: @selected_path_length, min_rounds: @selected_min_rounds,
                                      result_limit: @selected_result_limit, strategy_filter: @strategy_filter)
      @tech_paths = query.call
      @rounds_analysed = query.rounds_analysed
      @paths_found = query.paths_found
      @paths_above_minimum = query.paths_above_minimum
      @strategy_filter_options = query.filter_options

      render layout: 'full'
    end

    def tree
      @min_rounds_options = MARINE_GRAPH_MIN_ROUNDS_OPTIONS
      @selected_min_rounds = normalize_graph_min_rounds(params[:min_rounds], @min_rounds_options)
      query = MarineTechPathQuery.new(path_length: nil,
                                      min_rounds: @selected_min_rounds,
                                      result_limit: nil)
      @tech_paths = query.call
      @rounds_analysed = query.rounds_analysed
      @paths_found = query.paths_found
      @tech_tree_team = 'Marine'
      @tech_tree_step = 'research option'
      @tech_tree_rules = 'Each branch is a sequence of distinct research starts; Distress Beacon is excluded. ' \
                         'NS1 logs do not record completions or cancellations.'

      render layout: 'full'
    end

    def alien_tree
      @min_rounds_options = ALIEN_GRAPH_MIN_ROUNDS_OPTIONS
      @selected_min_rounds = normalize_graph_min_rounds(params[:min_rounds], @min_rounds_options)
      query = AlienTechPathQuery.new(path_length: nil,
                                     min_rounds: @selected_min_rounds,
                                     result_limit: nil)
      @tech_paths = query.call
      @rounds_analysed = query.rounds_analysed
      @paths_found = query.paths_found
      @tech_tree_team = 'Alien'
      @tech_tree_step = 'chamber choice'
      @tech_tree_rules = 'Each branch follows the first distinct chamber choices built in a round. ' \
                         'Repeated chambers do not add another choice.'

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

    private

    def normalize_graph_min_rounds(value, options)
      numeric = Integer(value, exception: false)
      options.include?(numeric) ? numeric : options.first
    end
  end
end
