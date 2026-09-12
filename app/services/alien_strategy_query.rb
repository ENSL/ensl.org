# frozen_string_literal: true

# Groups the per-round alien strategy output from ensl_analysis by six
# canonicalized player-role paths. Role slot numbers are deliberately ignored:
# the six paths are truncated to the action limit and then sorted, so swapping
# r1 and r2 never creates a different strategy.
class AlienStrategyQuery
  ACTION_LIMIT_OPTIONS = (1..10).to_a.freeze
  DEFAULT_ACTION_LIMIT = 3
  UNCAPPED_ACTION_LIMIT = 'all'

  MIN_ROUNDS_OPTIONS = [5, 10, 25, 50].freeze
  DEFAULT_MIN_ROUNDS = 5

  RESULT_LIMIT_OPTIONS = [10, 20, 25, 50, 100].freeze
  DEFAULT_RESULT_LIMIT = 20
  UNCAPPED_RESULT_LIMIT = 'all'

  def self.normalize_action_limit(value)
    return nil if value.to_s == UNCAPPED_ACTION_LIMIT

    ACTION_LIMIT_OPTIONS.include?(value.to_i) ? value.to_i : DEFAULT_ACTION_LIMIT
  end

  def self.normalize_min_rounds(value)
    MIN_ROUNDS_OPTIONS.include?(value.to_i) ? value.to_i : DEFAULT_MIN_ROUNDS
  end

  def self.normalize_result_limit(value)
    return nil if value.to_s == UNCAPPED_RESULT_LIMIT

    RESULT_LIMIT_OPTIONS.include?(value.to_i) ? value.to_i : DEFAULT_RESULT_LIMIT
  end

  def initialize(action_limit: DEFAULT_ACTION_LIMIT, min_rounds: DEFAULT_MIN_ROUNDS,
                 result_limit: DEFAULT_RESULT_LIMIT)
    @action_limit = action_limit
    @min_rounds = min_rounds
    @result_limit = result_limit
  end

  def call
    rows = qualifying_rows.sort_by { |row| [-row[:win_ratio], -row[:rounds]] }
    @result_limit ? rows.first(@result_limit) : rows
  end

  def rounds_analysed
    strategy_results.size
  end

  def strategies_found
    tally.size
  end

  def strategies_above_minimum
    qualifying_rows.size
  end

  def latest_batch_id
    @latest_batch_id ||= AnalysisResult.historical.where(model: 'alien_strategy').maximum(:batch_id)
  end

  private

  def qualifying_rows
    @qualifying_rows ||= tally.filter_map do |roles, counts|
      rounds = counts[:wins] + counts[:losses]
      next if rounds < @min_rounds

      { roles: roles, rounds: rounds, wins: counts[:wins], losses: counts[:losses],
        reach_rate: rounds * 100.0 / rounds_analysed,
        win_ratio: counts[:wins] * 100.0 / rounds,
        median_win_time: median(counts[:win_times]) }
    end
  end

  def tally
    empty_counts = Hash.new { |hash, key| hash[key] = { wins: 0, losses: 0, win_times: [] } }
    @tally ||= strategy_results.each_with_object(empty_counts) do |row, counts|
      outcome = row.metric == 'alien_win' ? :wins : :losses
      strategy_counts = counts[canonical_roles(row.steamid)]
      strategy_counts[outcome] += 1
      strategy_counts[:win_times] << row.value if outcome == :wins && row.value.positive?
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
                                          .where.not(steamid: [AnalysisResult::NO_STEAMID, nil]).to_a
                          else
                            []
                          end
  end

  def canonical_roles(strategy)
    roles = strategy.split(',').filter_map do |assignment|
      _slot, actions = assignment.split('=', 2)
      next unless actions

      path = actions.split('+')
      path = path.first(@action_limit) if @action_limit
      path.freeze
    end
    roles.sort_by { |path| [path == ['none'] ? 1 : 0, path.join('+')] }.freeze
  end
end
