# frozen_string_literal: true

require 'duckdb'

# Imports one export batch of ensl_analysis Python output into
# `analysis_results`. Each batch is expected to be a directory of Parquet
# files (Spark writes one or more part-*.parquet files per table, which is
# why we glob rather than assume a single file):
#
#   <exports_dir>/<batch_id>/analysis_results/*.parquet
#
# with columns steamid (nullable), model, metric, value, milestone
# (nullable). `batch_id` itself comes from the directory name, not from a
# column in the file, matching the same id the Python exporter assigns.
#
# WIP: barebones by design (see AnalysisResult). Not yet exercised against a
# real export -- the Python exporter is being written separately -- so column
# names/layout here may still need adjusting once that side exists.
class AnalysisBatchImportService
  Error = Class.new(StandardError)

  DEFAULT_EXPORTS_DIR = Rails.root.join('storage', 'analysis_exports').to_s
  UPSERT_SLICE_SIZE = 1000

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
      AnalysisResult.upsert_all(slice, record_timestamps: false)
    end

    Rails.logger.info("[AnalysisBatchImportService] Imported #{rows.size} rows for batch #{@batch_id}")
    rows.size
  end

  private

  def read_rows
    database = DuckDB::Database.open
    connection = database.connect
    imported_at = Time.current

    result = connection.query(<<~SQL)
      SELECT steamid, model, metric, value, milestone
      FROM read_parquet('#{parquet_glob}')
    SQL

    result.map do |(steamid, model, metric, value, milestone)|
      {
        batch_id: @batch_id,
        steamid: steamid,
        model: model,
        metric: metric,
        value: value,
        milestone: milestone,
        created_at: imported_at,
      }
    end
  ensure
    connection&.close
    database&.close
  end

  # Resolves and validates the batch directory, guarding against a batch_id
  # or exports_dir override that would resolve outside of @exports_dir.
  def parquet_glob
    batch_dir = File.expand_path(File.join(@exports_dir, @batch_id.to_s, 'analysis_results'))

    unless batch_dir.start_with?("#{@exports_dir}/")
      raise Error, "Resolved batch path escapes exports dir: #{batch_dir}"
    end

    unless Dir.exist?(batch_dir)
      raise Error, "No exported analysis_results found for batch #{@batch_id} at #{batch_dir}"
    end

    File.join(batch_dir, '*.parquet')
  end
end
