# frozen_string_literal: true

require 'duckdb'

# Imports one export batch of ensl_analysis Python output into
# `analysis_results`. Everything lands in that one table (see AnalysisResult)
# -- there's no per-source model, just different (model, metric) values on
# the same row shape. A batch is a directory of sub-directories, each holding
# one or more Spark part-*.parquet files:
#
#   <exports_dir>/<batch_id>/analysis_results/*.parquet  (legacy WIP layout)
#   <exports_dir>/<batch_id>/metrics/*.parquet           (per-model aggregates)
#   <exports_dir>/<batch_id>/skill_<model>/*.parquet     (per-player model output)
#   <exports_dir>/<batch_id>/users/*.parquet             (player stats + steamid lookup)
#   <exports_dir>/<batch_id>/map_balance/*.parquet       (per-map win rates)
#   <exports_dir>/<batch_id>/time_of_week/*.parquet      (round counts per hour-of-week)
#
# All sub-directories are optional -- a batch only needs to contain whichever
# of these the exporter produced that run -- except the whole thing raises if
# NONE of them are present (almost certainly a bad batch_id/exports_dir).
#
# Two very different storage semantics share this table, distinguished by
# batch_id (see AnalysisResult::CURRENT_SNAPSHOT_BATCH_ID):
#
# * Historical (append-only): player stats and per-model skill values. Each
#   batch's rows are additional history, never overwritten -- that's the
#   existing behaviour, keyed on the real batch_id.
# * Overwritable (current-state snapshot): map balance and time-of-week
#   activity aren't per-player history, they're "what does the world look
#   like right now" aggregates recomputed from the full dataset on every
#   run. Re-importing must replace the old numbers, not pile up near-dupes,
#   so these rows are upserted under the fixed CURRENT_SNAPSHOT_BATCH_ID
#   instead of the batch's own id.
class AnalysisBatchImportService
  Error = Class.new(StandardError)

  DEFAULT_EXPORTS_DIR = Rails.root.join('storage/analysis_exports').to_s
  UPSERT_SLICE_SIZE = 1000

  # Per-player skill/rating model directories (`skill_<key>/*.parquet`), each
  # keyed by `user_id`, mapped to the (metric => column) pairs we pull out of
  # them. `model` in analysis_results is the hash key below.
  SKILL_MODEL_METRIC_COLUMNS = {
    'dl' => { 'skill' => 'skill_dl' },
    'mlt' => { 'skill' => 'skill_mlt' },
    'os' => { 'mu' => 'mu_os', 'sigma' => 'sigma_os', 'skill' => 'skill_os' },
    'os_btf' => { 'mu' => 'mu_os_btf', 'sigma' => 'sigma_os_btf', 'skill' => 'skill_os_btf' },
    'os_btp' => { 'mu' => 'mu_os_btp', 'sigma' => 'sigma_os_btp', 'skill' => 'skill_os_btp' },
    'os_tmf' => { 'mu' => 'mu_os_tmf', 'sigma' => 'sigma_os_tmf', 'skill' => 'skill_os_tmf' }
  }.freeze

  # Columns pulled from `users/*.parquet` as historical per-player stats.
  # `skill` is intentionally excluded -- it's not used yet, and the real
  # per-model skill values are covered by SKILL_MODEL_METRIC_COLUMNS above.
  PLAYER_STAT_METRICS = %w[wins losses win_ratio].freeze

  # Columns pulled from `map_balance/*.parquet`, one analysis_results row per
  # (map, metric).
  MAP_BALANCE_METRICS = %w[marine_wins alien_wins total_games marine_win_percentage alien_win_percentage].freeze

  def initialize(batch_id, exports_dir: nil)
    @batch_id = Integer(batch_id)
    @exports_dir = File.expand_path(exports_dir || ENV.fetch('ANALYSIS_EXPORTS_DIR', DEFAULT_EXPORTS_DIR))
  end

  # Returns the number of rows imported (upserted) for this batch.
  def call
    rows = read_rows
    return 0 if rows.empty?

    rows.each_slice(UPSERT_SLICE_SIZE) do |slice|
      # unique_by is intentionally omitted: MySQL doesn't support it (Rails
      # raises if you pass it) and instead upserts against whichever unique
      # index the row collides with -- here that's
      # index_analysis_results_on_batch_and_subject.
      # rubocop:disable Rails/SkipsModelValidations -- bulk import of already-validated
      # analysis output; per-row callbacks/validations would be prohibitively slow here.
      AnalysisResult.upsert_all(slice, record_timestamps: false)
      # rubocop:enable Rails/SkipsModelValidations
    end

    Rails.logger.info("[AnalysisBatchImportService] Imported #{rows.size} rows for batch #{@batch_id}")
    rows.size
  end

  private

  def read_rows
    database = DuckDB::Database.open
    connection = database.connect
    imported_at = Time.current

    rows = [
      read_legacy_rows(connection, imported_at),
      read_skill_model_rows(connection, imported_at),
      read_player_stat_rows(connection, imported_at),
      read_map_balance_rows(connection, imported_at),
      read_time_of_week_rows(connection, imported_at)
    ].flatten(1)

    return rows if rows.any?

    raise Error, "No recognized exports found for batch #{@batch_id} under #{batch_dir}"
  ensure
    connection&.close
    database&.close
  end

  # Legacy/aggregate sources: an older WIP layout wrote a single
  # `analysis_results` directory with the final column shape already; the
  # current exporter instead writes per-model aggregate metrics (no
  # steamid) under `metrics`. Both are historical, keyed on the real
  # batch_id, same as before this importer grew the sources below.
  def read_legacy_rows(connection, imported_at)
    if (glob = existing_glob('analysis_results'))
      sql = "SELECT steamid, model, metric, value, milestone FROM read_parquet('#{glob}')"
    elsif (glob = existing_glob('metrics'))
      sql = "SELECT NULL::VARCHAR AS steamid, name AS model, metric, value, milestone FROM read_parquet('#{glob}')"
    else
      return []
    end

    connection.query(sql).map do |(steamid, model, metric, value, milestone)|
      historical_row(imported_at, steamid: steamid, model: model, metric: metric, value: value, milestone: milestone)
    end
  end

  # Per-player skill/rating output, one directory per model. `user_id` only
  # means something inside this export batch's own `users` table, so we
  # join it there to resolve the steamid we actually key on.
  def read_skill_model_rows(connection, imported_at)
    users_glob = existing_glob('users')
    return [] unless users_glob

    SKILL_MODEL_METRIC_COLUMNS.flat_map do |model, metric_columns|
      skill_glob = existing_glob("skill_#{model}")
      next [] unless skill_glob

      metric_columns.flat_map do |metric, column|
        sql = <<~SQL.squish
          SELECT u.steam_id, s.#{column}
          FROM read_parquet('#{skill_glob}') s
          JOIN read_parquet('#{users_glob}') u ON s.user_id = u.id
          WHERE s.#{column} IS NOT NULL
        SQL

        connection.query(sql).map do |(steamid, value)|
          historical_row(imported_at, steamid: steamid, model: model, metric: metric, value: value, milestone: nil)
        end
      end
    end
  end

  # Historical per-player stats (skill excluded -- not used yet).
  def read_player_stat_rows(connection, imported_at)
    users_glob = existing_glob('users')
    return [] unless users_glob

    PLAYER_STAT_METRICS.flat_map do |metric|
      sql = <<~SQL.squish
        SELECT steam_id, #{metric}
        FROM read_parquet('#{users_glob}')
        WHERE #{metric} IS NOT NULL
      SQL

      connection.query(sql).map do |(steamid, value)|
        historical_row(imported_at, steamid: steamid, model: 'player_stats', metric: metric, value: value,
                                    milestone: nil)
      end
    end
  end

  # Overwritable: per-map win rates, keyed on map_name (reusing `steamid` as
  # the generic subject column, same as `metrics` already does for
  # model-level aggregates).
  def read_map_balance_rows(connection, imported_at)
    glob = existing_glob('map_balance')
    return [] unless glob

    MAP_BALANCE_METRICS.flat_map do |metric|
      sql = <<~SQL.squish
        SELECT map_name, #{metric}
        FROM read_parquet('#{glob}')
        WHERE #{metric} IS NOT NULL
      SQL

      connection.query(sql).map do |(map_name, value)|
        current_snapshot_row(imported_at, steamid: map_name, model: 'map_balance', metric: metric, value: value,
                                          milestone: nil)
      end
    end
  end

  # Overwritable: round counts per hour-of-week. day_of_week (0-6) reuses
  # `steamid` as the generic subject column; hour_of_day (0-23) fits the
  # existing `milestone` bucket column.
  def read_time_of_week_rows(connection, imported_at)
    glob = existing_glob('time_of_week')
    return [] unless glob

    sql = <<~SQL.squish
      SELECT day_of_week, hour_of_day, round_count
      FROM read_parquet('#{glob}')
      WHERE round_count IS NOT NULL
    SQL

    connection.query(sql).map do |(day_of_week, hour_of_day, round_count)|
      current_snapshot_row(imported_at, steamid: day_of_week.to_s, model: 'time_of_week', metric: 'round_count',
                                        value: round_count, milestone: hour_of_day)
    end
  end

  # `attrs` is {steamid:, model:, metric:, value:, milestone:} -- bundled into
  # one hash (rather than five keyword params) to keep this under RuboCop's
  # parameter-count limit without losing the self-documenting call sites.
  def historical_row(imported_at, attrs)
    {
      batch_id: @batch_id,
      # NULL is deliberately never written here -- see
      # AnalysisResult::NO_STEAMID/NO_MILESTONE for why.
      steamid: attrs[:steamid] || AnalysisResult::NO_STEAMID,
      model: attrs[:model],
      metric: attrs[:metric],
      value: attrs[:value],
      milestone: attrs[:milestone] || AnalysisResult::NO_MILESTONE,
      created_at: imported_at
    }
  end

  def current_snapshot_row(imported_at, attrs)
    historical_row(imported_at, attrs).merge(batch_id: AnalysisResult::CURRENT_SNAPSHOT_BATCH_ID)
  end

  def batch_dir
    File.expand_path(File.join(@exports_dir, @batch_id.to_s))
  end

  # Resolves `<batch_dir>/<subdir>/*.parquet`, guarding against a batch_id or
  # exports_dir override that would resolve outside of @exports_dir. Returns
  # nil (rather than raising) when the sub-directory doesn't exist or is
  # empty, since every source this importer reads is optional.
  def existing_glob(subdir)
    dir = File.expand_path(File.join(batch_dir, subdir))
    raise Error, "Resolved batch path escapes exports dir: #{dir}" unless dir.start_with?("#{@exports_dir}/")

    glob = File.join(dir, '*.parquet')
    glob if Dir.exist?(dir) && Dir.glob(glob).any?
  end
end
