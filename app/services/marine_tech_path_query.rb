# frozen_string_literal: true

# Groups rounds by the marine commander's opening tech path -- the ordered
# sequence of the first N distinct researches started -- and reports how
# often each path won. Used by Analysis::TechPathsController#index.
#
# Unlike the other Analysis:: listings this reads the raw imported log data
# (LogLine `research_start` events, see /memories/repo/round-timeline.md)
# rather than a precomputed AnalysisResult snapshot, since the pipeline does
# not export anything tech-tree shaped yet.
#
# Caveats baked into the numbers, all forced by what the NS1 logs actually
# record:
# * There is no `research_complete` event, only starts -- a path here means
#   "what the commander went for", not "what finished".
# * `research_cancel` events carry no type (param1 is always nil), so a
#   cancelled research cannot be matched back to its start and is counted.
# * Re-starting the same research (after a cancel, or on a second Arms Lab)
#   is deduplicated: only the first start of each type counts towards order.
class MarineTechPathQuery
  # A distress beacon says nothing about a commander's plan -- it is a panic
  # button, and the single most-started research in the data, so leaving it in
  # drowns out every actual tech choice.
  EXCLUDED_RESEARCH = %w[research_distressbeacon].freeze

  # The longest opening prefix to include. A nil path_length includes every
  # prefix in a round's complete research order.
  PATH_LENGTH_OPTIONS = (1..10).to_a.freeze
  DEFAULT_PATH_LENGTH = 3
  UNCAPPED_PATH_LENGTH = 'all'

  MIN_ROUNDS_OPTIONS = [5, 10, 25, 50].freeze
  DEFAULT_MIN_ROUNDS = 5

  RESULT_LIMIT_OPTIONS = [10, 20, 25, 50, 100].freeze
  DEFAULT_RESULT_LIMIT = 20
  UNCAPPED_RESULT_LIMIT = 'all'

  def self.call(path_length: DEFAULT_PATH_LENGTH, min_rounds: DEFAULT_MIN_ROUNDS,
                result_limit: DEFAULT_RESULT_LIMIT)
    new(path_length: path_length, min_rounds: min_rounds, result_limit: result_limit).call
  end

  # Both normalizers exist for the controller's benefit: query string values
  # are untrusted, and path_length in particular drives how much work the
  # tally does, so it is clamped to a known-good option before it gets here.
  # Returns nil for the uncapped option.
  def self.normalize_path_length(value)
    return nil if value.to_s == UNCAPPED_PATH_LENGTH

    PATH_LENGTH_OPTIONS.include?(value.to_i) ? value.to_i : DEFAULT_PATH_LENGTH
  end

  def self.normalize_min_rounds(value)
    MIN_ROUNDS_OPTIONS.include?(value.to_i) ? value.to_i : DEFAULT_MIN_ROUNDS
  end

  def self.normalize_result_limit(value)
    return nil if value.to_s == UNCAPPED_RESULT_LIMIT

    RESULT_LIMIT_OPTIONS.include?(value.to_i) ? value.to_i : DEFAULT_RESULT_LIMIT
  end

  def initialize(path_length: DEFAULT_PATH_LENGTH, min_rounds: DEFAULT_MIN_ROUNDS,
                 result_limit: DEFAULT_RESULT_LIMIT)
    @path_length = path_length
    @min_rounds = min_rounds
    @result_limit = result_limit
  end

  # Returns an array of hashes: { path: [research keys], rounds:, wins:,
  # losses:, win_ratio: (0-100) }, best win ratio first. A nil result_limit
  # returns every path which meets the minimum round count.
  def call
    rows = qualifying_rows.sort_by { |row| [-row[:win_ratio], -row[:rounds]] }
    @result_limit ? rows.first(@result_limit) : rows
  end

  # Total number of rounds that contributed to the tally, before the
  # min_rounds cutoff -- shown as context so a tiny sample is obvious.
  def rounds_analysed
    paths_by_round.size
  end

  # How many distinct opening prefixes exist at the selected maximum length.
  def paths_found
    tally.size
  end

  # Of those, how many were taken in at least min_rounds rounds.
  def paths_above_minimum
    qualifying_rows.size
  end

  private

  def qualifying_rows
    @qualifying_rows ||= tally.filter_map do |path, counts|
      rounds = counts[:wins] + counts[:losses]
      next if rounds < @min_rounds

      { path: path, rounds: rounds, wins: counts[:wins], losses: counts[:losses],
        win_ratio: (counts[:wins] * 100.0 / rounds) }
    end
  end

  def tally
    @tally ||= begin
      counts = Hash.new { |hash, key| hash[key] = { wins: 0, losses: 0 } }
      paths_by_round.each do |round_id, full_path|
        outcome = results_by_round[round_id] == Round::RESULT_MARINE_WIN ? :wins : :losses
        maximum_length = @path_length || full_path.length
        full_path.first(maximum_length).each_index do |index|
          counts[full_path.first(index + 1)][outcome] += 1
        end
      end
      counts
    end
  end

  # round_id -> every distinct research started by the marine commander.
  def paths_by_round
    @paths_by_round ||= begin
      ordered = Hash.new { |hash, key| hash[key] = [] }
      research_events.each do |round_id, research|
        path = ordered[round_id]
        path << research unless path.include?(research)
      end
      ordered.transform_values(&:freeze)
    end
  end

  def research_events
    Round.where.not(result: nil)
         .joins(:log_lines)
         .where(log_lines: { event_type: 'research_start' })
         .where.not(log_lines: { param1: EXCLUDED_RESEARCH + [nil] })
         .order('log_lines.created_at', 'log_lines.id')
         .pluck('log_lines.round_id', 'log_lines.param1')
  end

  def results_by_round
    @results_by_round ||= Round.where(id: paths_by_round.keys).pluck(:id, :result).to_h
  end
end
