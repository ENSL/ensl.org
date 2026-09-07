# frozen_string_literal: true

module Analysis
  # /analysis/tech_paths -- the marine opening tech orders with the best win
  # rates, derived from raw `research_start` log lines by
  # MarineTechPathQuery. Aliens have no equivalent research events in the
  # logs (their upgrades are chambers, i.e. `structure_built`), so this page
  # is marine-only for now.
  class TechPathsController < Analysis::BaseController
    def index
      @path_length_options = MarineTechPathQuery::PATH_LENGTH_OPTIONS
      @selected_path_length = MarineTechPathQuery.normalize_path_length(params[:path_length])
      @min_rounds_options = MarineTechPathQuery::MIN_ROUNDS_OPTIONS
      @selected_min_rounds = MarineTechPathQuery.normalize_min_rounds(params[:min_rounds])
      @result_limit_options = MarineTechPathQuery::RESULT_LIMIT_OPTIONS
      @selected_result_limit = MarineTechPathQuery.normalize_result_limit(params[:result_limit])

      query = MarineTechPathQuery.new(path_length: @selected_path_length, min_rounds: @selected_min_rounds,
                                      result_limit: @selected_result_limit)
      @tech_paths = query.call
      @rounds_analysed = query.rounds_analysed
      @paths_found = query.paths_found
      @paths_above_minimum = query.paths_above_minimum

      render layout: 'full'
    end
  end
end
