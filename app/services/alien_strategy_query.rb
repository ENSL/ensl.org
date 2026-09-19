# frozen_string_literal: true

# Groups the per-round alien strategy output from ensl_analysis by six
# canonicalized player-role paths. Role slot numbers are deliberately ignored:
# the six paths are truncated to the action limit and then sorted, so swapping
# r1 and r2 never creates a different strategy.
class AlienStrategyQuery
  ACTION_LIMIT_OPTIONS = (1..10).to_a.freeze
  UNCAPPED_ACTION_LIMIT = 'all'
  BEST_ACTION_LIMIT = 'best'
  DEFAULT_ACTION_LIMIT = BEST_ACTION_LIMIT

  MIN_ROUNDS_OPTIONS = [5, 10, 25, 50].freeze
  DEFAULT_MIN_ROUNDS = 25

  RESULT_LIMIT_OPTIONS = [10, 20, 25, 50, 100].freeze
  DEFAULT_RESULT_LIMIT = 25
  UNCAPPED_RESULT_LIMIT = 'all'

  RESULT_VIEW_OPTIONS = %w[role_actions strategies].freeze
  DEFAULT_RESULT_VIEW = 'strategies'

  MIN_MEDIAN_WIN_TIME_OPTIONS = [300, 600, 900, 1200, 1500, 1800].freeze
  COALESCED_CHAMBER_ACTIONS = { 'dcs' => 'dc', 'mcs' => 'mc', 'ocs' => 'oc', 'scs' => 'sc' }.freeze

  def self.from_params(params)
    new(action_limit: normalize_action_limit(params[:action_limit]),
        min_rounds: normalize_min_rounds(params[:min_rounds]),
        result_limit: normalize_result_limit(params[:result_limit]),
        result_view: normalize_result_view(params[:result_view]),
        min_median_win_time: normalize_min_median_win_time(params[:min_median_win_time]),
        strategy_filter: normalize_strategy_filter(params[:strategy_filter]),
        coalesce_chambers: normalize_coalesce_chambers(params[:coalesce_chambers]))
  end

  def self.normalize_action_limit(value)
    return nil if value.to_s == UNCAPPED_ACTION_LIMIT
    return BEST_ACTION_LIMIT if value.to_s == BEST_ACTION_LIMIT

    ACTION_LIMIT_OPTIONS.include?(value.to_i) ? value.to_i : DEFAULT_ACTION_LIMIT
  end

  def self.normalize_min_rounds(value)
    MIN_ROUNDS_OPTIONS.include?(value.to_i) ? value.to_i : DEFAULT_MIN_ROUNDS
  end

  def self.normalize_result_limit(value)
    return nil if value.to_s == UNCAPPED_RESULT_LIMIT

    RESULT_LIMIT_OPTIONS.include?(value.to_i) ? value.to_i : DEFAULT_RESULT_LIMIT
  end

  def self.normalize_result_view(value)
    RESULT_VIEW_OPTIONS.include?(value) ? value : DEFAULT_RESULT_VIEW
  end

  def self.normalize_min_median_win_time(value)
    return nil if value.blank?

    MIN_MEDIAN_WIN_TIME_OPTIONS.include?(value.to_i) ? value.to_i : nil
  end

  def self.normalize_strategy_filter(value)
    value.to_s.downcase.split(/[^a-z0-9]+/).reject(&:blank?).join('+')
  end

  def self.normalize_coalesce_chambers(value)
    value == '1'
  end

  def initialize(action_limit: DEFAULT_ACTION_LIMIT, min_rounds: DEFAULT_MIN_ROUNDS,
                 result_limit: DEFAULT_RESULT_LIMIT, result_view: DEFAULT_RESULT_VIEW,
                 min_median_win_time: nil, strategy_filter: nil, coalesce_chambers: false)
    @action_limit = action_limit
    @min_rounds = min_rounds
    @result_limit = result_limit
    @result_view = result_view
    @min_median_win_time = min_median_win_time
    @strategy_filter = self.class.normalize_strategy_filter(strategy_filter)
    @coalesce_chambers = coalesce_chambers
  end

  def call
    rows = filtered_result_rows.sort_by { |row| [-row[:win_ratio], -row[:rounds]] }
    @result_limit ? rows.first(@result_limit) : rows
  end

  def report
    { action_limit_options: ACTION_LIMIT_OPTIONS, selected_action_limit: @action_limit,
      min_rounds_options: MIN_ROUNDS_OPTIONS, selected_min_rounds: @min_rounds,
      result_limit_options: RESULT_LIMIT_OPTIONS, selected_result_limit: @result_limit,
      selected_result_view: @result_view,
      min_median_win_time_options: MIN_MEDIAN_WIN_TIME_OPTIONS,
      selected_min_median_win_time: @min_median_win_time, strategy_filter: @strategy_filter,
      coalesce_chambers: @coalesce_chambers, strategies: call, batch_id: latest_batch_id,
      rounds_analysed: rounds_analysed, strategies_found: strategies_found,
      strategy_filter_options: filter_options }
  end

  def rounds_analysed
    strategy_results.size
  end

  def strategies_found
    @action_limit == BEST_ACTION_LIMIT ? best_candidate_rows.size : tally.size
  end

  def latest_batch_id
    @latest_batch_id ||= AnalysisResult.historical.where(model: 'alien_strategy').maximum(:batch_id)
  end

  # Tokens accepted by the Contains filter, after applying the selected chamber
  # coalescing rule so suggestions always match the displayed strategies.
  def filter_options
    strategy_results.flat_map { |result| canonical_roles(result.steamid).flatten }.uniq.sort
  end

  private

  def result_rows
    @result_rows ||= begin
      rows = @action_limit == BEST_ACTION_LIMIT ? best_candidate_rows : selected_result_rows
      rows.select do |row|
        @min_median_win_time.nil? || row[:median_win_time] && row[:median_win_time] >= @min_median_win_time
      end
    end
  end

  def selected_result_rows(action_limit = @action_limit)
    @result_view == 'role_actions' ? qualifying_role_action_rows(action_limit) : qualifying_rows(action_limit)
  end

  def best_candidate_rows
    @best_candidate_rows ||= begin
      rows = (ACTION_LIMIT_OPTIONS + [nil]).flat_map do |action_limit|
        selected_result_rows(action_limit).map { |row| row.merge(action_limit: action_limit) }
      end

      rows.each_with_object({}) do |row, unique_rows|
        # Longer limits can reproduce an identical group when no player took another action.
        unique_rows[best_row_key(row)] ||= row
      end.values
    end
  end

  def best_row_key(row)
    group = @result_view == 'role_actions' ? row[:role] : row[:roles]
    [group, row[:rounds], row[:wins], row[:losses], row[:median_win_time]]
  end

  def qualifying_rows(action_limit = @action_limit)
    @qualifying_rows ||= {}
    @qualifying_rows[action_limit] ||= tally(action_limit).filter_map do |roles, counts|
      rounds = counts[:wins] + counts[:losses]
      next if rounds < @min_rounds

      { roles: roles, rounds: rounds, wins: counts[:wins], losses: counts[:losses],
        reach_rate: rounds * 100.0 / rounds_analysed,
        win_ratio: counts[:wins] * 100.0 / rounds,
        median_win_time: median(counts[:win_times]) }
    end
  end

  def qualifying_role_action_rows(action_limit = @action_limit)
    @qualifying_role_action_rows ||= {}
    @qualifying_role_action_rows[action_limit] ||= role_action_tally(action_limit).filter_map do |role, counts|
      rounds = counts[:wins] + counts[:losses]
      next if rounds < @min_rounds

      { role: role, rounds: rounds, wins: counts[:wins], losses: counts[:losses],
        reach_rate: rounds * 100.0 / rounds_analysed,
        win_ratio: counts[:wins] * 100.0 / rounds,
        median_win_time: median(counts[:win_times]) }
    end
  end

  def tally(action_limit = @action_limit)
    empty_counts = Hash.new { |hash, key| hash[key] = { wins: 0, losses: 0, win_times: [] } }
    @tallies ||= {}
    @tallies[action_limit] ||= strategy_results.each_with_object(empty_counts) do |row, counts|
      outcome = row.metric == 'alien_win' ? :wins : :losses
      strategy_counts = counts[canonical_roles(row.steamid, action_limit)]
      strategy_counts[outcome] += 1
      strategy_counts[:win_times] << row.value if outcome == :wins && row.value.positive?
    end
  end

  def role_action_tally(action_limit = @action_limit)
    empty_counts = Hash.new { |hash, key| hash[key] = { wins: 0, losses: 0, win_times: [] } }
    @role_action_tallies ||= {}
    @role_action_tallies[action_limit] ||= strategy_results.each_with_object(empty_counts) do |row, counts|
      outcome = row.metric == 'alien_win' ? :wins : :losses
      canonical_roles(row.steamid, action_limit).uniq.each do |role|
        role_counts = counts[role]
        role_counts[outcome] += 1
        role_counts[:win_times] << row.value if outcome == :wins && row.value.positive?
      end
    end
  end

  def median(values)
    return if values.empty?

    sorted = values.sort
    middle = sorted.length / 2
    sorted.length.odd? ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2.0
  end

  def strategy_results
    @strategy_results ||= if latest_batch_id
                            AnalysisResult.historical.where(batch_id: latest_batch_id, model: 'alien_strategy')
                                          .where(metric: %w[alien_win marine_win])
                                          .where.not(steamid: [AnalysisResult::NO_STEAMID, nil])
                                          .then { |scope| filter_strategy_results(scope) }.to_a
                          else
                            []
                          end
  end

  def canonical_roles(strategy, action_limit = @action_limit)
    roles = strategy.split(',').filter_map do |assignment|
      slot, actions = assignment.split('=', 2)
      actions ||= slot

      path = actions.split('+').map { |action| canonical_action(action) }
      path = path.first(action_limit) if action_limit.is_a?(Integer)
      path.freeze
    end
    roles.sort_by { |path| [path == ['none'] ? 1 : 0, path.join('+')] }.freeze
  end

  def filter_strategy_results(scope)
    scope
  end

  def filtered_result_rows
    return result_rows if @strategy_filter.blank?

    terms = @strategy_filter.split('+')
    result_rows.select do |row|
      paths = @result_view == 'role_actions' ? [row[:role]] : row[:roles]
      paths.any? { |path| terms.all? { |term| path.include?(term) } }
    end
  end

  def canonical_action(action)
    @coalesce_chambers ? COALESCED_CHAMBER_ACTIONS.fetch(action, action) : action
  end
end
