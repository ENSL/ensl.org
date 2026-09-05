# frozen_string_literal: true

require 'duckdb'
require 'digest'

# Imports the round/log side of one ensl_analysis export batch --
# `rounds`, `round_users`, `log_files`, and `log_lines` parquet dirs -- into
# the Round, Rounder, LogFile, and LogLine tables. Same
# `<exports_dir>/<batch_id>/...` layout as AnalysisBatchImportService (see
# that class), just a different set of sub-directories:
#
#   <exports_dir>/<batch_id>/log_files/*.parquet
#   <exports_dir>/<batch_id>/rounds/*.parquet
#   <exports_dir>/<batch_id>/round_users/*.parquet
#   <exports_dir>/<batch_id>/log_lines/*.parquet
#   <exports_dir>/<batch_id>/users/*.parquet   (needed to resolve steamids)
#
# Unlike AnalysisResult, none of this data is kept as append-only
# batch_id history -- there's no Python-side id here that's stable across
# batches (see the RestructureRoundAndLogModels migration for why), and
# re-running the pipeline can re-emit rows already imported for a changed
# log file. So everything is upserted by a natural key derived from the
# underlying log content instead, and `batch_id` is only used to locate the
# export directory, never stored.
#
# Import order matters: rounds and log_files are imported first so their
# Rails-assigned ids can be resolved (by natural key) for round_users and
# log_lines, which reference them via the Python exporter's own unstable ids.
class RoundBatchImportService
  Error = Class.new(StandardError)

  DEFAULT_EXPORTS_DIR = Rails.root.join('storage/analysis_exports').to_s
  UPSERT_SLICE_SIZE = 1000

  def initialize(batch_id, exports_dir: nil)
    @batch_id = Integer(batch_id)
    @exports_dir = File.expand_path(exports_dir || ENV.fetch('ANALYSIS_EXPORTS_DIR', DEFAULT_EXPORTS_DIR))
  end

  # Returns a hash of imported row counts per table, e.g.
  # { log_files: 1, rounds: 12, rounders: 34, log_lines: 560 }.
  def call
    database = DuckDB::Database.open
    connection = database.connect

    counts = {
      log_files: upsert(LogFile, read_log_files(connection)),
      rounds: upsert(Round, read_rounds(connection))
    }
    # Rounders/log_lines resolve their round_id/log_file_id against what was
    # just imported above, so the id maps must be rebuilt after that upsert.
    counts[:rounders] = upsert(Rounder, read_rounders(connection))
    counts[:log_lines] = upsert(LogLine, read_log_lines(connection))

    if counts.values.sum.zero?
      raise Error, "No recognized exports found for batch #{@batch_id} under #{batch_dir}"
    end

    Rails.logger.info("[RoundBatchImportService] Imported #{counts} for batch #{@batch_id}")
    counts
  ensure
    connection&.close
    database&.close
  end

  private

  def upsert(model, rows)
    return 0 if rows.empty?

    rows.each_slice(UPSERT_SLICE_SIZE) do |slice|
      # rubocop:disable Rails/SkipsModelValidations -- bulk import of already-validated
      # analysis output; per-row callbacks/validations would be prohibitively slow here.
      model.upsert_all(slice, record_timestamps: false)
      # rubocop:enable Rails/SkipsModelValidations
    end
    rows.size
  end

  def read_log_files(connection)
    glob = existing_glob('log_files')
    return [] unless glob

    sql = <<~SQL.squish
      SELECT sha256, filename, server_name, date_trunc('second', created_at) AS created_at
      FROM read_parquet('#{glob}')
    SQL

    connection.query(sql).map do |(sha256, filename, server_name, created_at)|
      { sha256: sha256, filename: filename, server_name: server_name, created_at: created_at }
    end
  end

  def read_rounds(connection)
    glob = existing_glob('rounds')
    return [] unless glob

    sql = <<~SQL.squish
      SELECT server_name, date_trunc('second', start_time) AS start_time,
             date_trunc('second', end_time) AS end_time, map_name, result
      FROM read_parquet('#{glob}')
    SQL

    connection.query(sql).map do |(server_name, start_time, end_time, map_name, result)|
      { server_name: server_name, start_time: start_time, end_time: end_time, map_name: map_name, result: result }
    end
  end

  # Joins round_users -> rounds (to resolve our round id) and -> users (to
  # resolve the player's steamid). Requires both sibling exports to be
  # present in the same batch -- round_users on its own has nothing to key
  # into our tables with.
  def read_rounders(connection)
    round_users_glob = existing_glob('round_users')
    rounds_glob = existing_glob('rounds')
    users_glob = existing_glob('users')
    return [] unless round_users_glob && rounds_glob && users_glob

    sql = <<~SQL.squish
      SELECT r.server_name, date_trunc('second', r.start_time) AS start_time, u.steam_id, ru.team, ru.share
      FROM read_parquet('#{round_users_glob}') ru
      JOIN read_parquet('#{rounds_glob}') r ON ru.round_id = r.id
      JOIN read_parquet('#{users_glob}') u ON ru.user_id = u.id
    SQL

    connection.query(sql).filter_map do |(server_name, start_time, steamid, team, share)|
      round_id = round_id_for(server_name, start_time)
      next unless round_id

      { round_id: round_id, steamid: steamid, team: team, share: share }
    end
  end

  # Joins log_lines -> rounds/log_files/users (twice, for actor and target)
  # to resolve every FK by natural key. Requires all three sibling exports
  # -- a log_lines export with none of its context is not useful to import.
  def read_log_lines(connection)
    log_lines_glob = existing_glob('log_lines')
    rounds_glob = existing_glob('rounds')
    log_files_glob = existing_glob('log_files')
    users_glob = existing_glob('users')
    return [] unless log_lines_glob && rounds_glob && log_files_glob && users_glob

    sql = <<~SQL.squish
      SELECT ll.raw_text, ll.event_type, ll.param1, ll.param2, ll.param3,
             r.server_name AS round_server_name, date_trunc('second', r.start_time) AS round_start_time,
             lf.sha256 AS log_file_sha256, au.steam_id AS actor_steamid, tu.steam_id AS target_steamid,
             ll.server_name, date_trunc('second', ll.created_at) AS created_at
      FROM read_parquet('#{log_lines_glob}') ll
      LEFT JOIN read_parquet('#{rounds_glob}') r ON ll.round_id = r.id
      LEFT JOIN read_parquet('#{log_files_glob}') lf ON ll.log_file_id = lf.id
      LEFT JOIN read_parquet('#{users_glob}') au ON ll.actor_id = au.id
      LEFT JOIN read_parquet('#{users_glob}') tu ON ll.target_id = tu.id
    SQL

    connection.query(sql).filter_map do |(raw_text, event_type, param1, param2, param3, round_server_name,
                                            round_start_time, log_file_sha256, actor_steamid, target_steamid,
                                            server_name, created_at)|
      log_file_id = log_file_id_for(log_file_sha256)
      next unless log_file_id # every log line came from some log file; skip if that file wasn't imported

      {
        log_file_id: log_file_id,
        round_id: round_id_for(round_server_name, round_start_time),
        raw_text: raw_text,
        event_type: event_type,
        param1: param1,
        param2: param2,
        param3: param3,
        actor_steamid: actor_steamid,
        target_steamid: target_steamid,
        server_name: server_name,
        created_at: created_at,
        line_digest: Digest::SHA256.hexdigest(raw_text.to_s)
      }
    end
  end

  # (server_name, start_time) -> our Round#id, for resolving the Python
  # exporter's unstable round_id in round_users/log_lines. Keyed on a plain
  # UTC-second string rather than the Time objects themselves, since a
  # DuckDB-sourced Time and an ActiveRecord-cast one for the same instant
  # aren't guaranteed to be `eql?`/hash-equal.
  def round_id_map
    @round_id_map ||= Round.pluck(:server_name, :start_time, :id).each_with_object({}) do |row, map|
      server_name, start_time, id = row
      map[[server_name, time_key(start_time)]] = id
    end
  end

  def round_id_for(server_name, start_time)
    return nil if server_name.nil? || start_time.nil?

    round_id_map[[server_name, time_key(start_time)]]
  end

  def log_file_id_map
    @log_file_id_map ||= LogFile.pluck(:sha256, :id).to_h
  end

  def log_file_id_for(sha256)
    return nil if sha256.nil?

    log_file_id_map[sha256]
  end

  def time_key(value)
    return nil if value.nil?

    value.to_time.utc.strftime('%Y-%m-%d %H:%M:%S')
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
