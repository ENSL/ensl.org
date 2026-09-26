# frozen_string_literal: true

require 'duckdb'
require 'digest'

# Imports every analytical Parquet relation as generic, typed cells. The raw
# round/log exports remain exclusively owned by RoundBatchImportService.
class AnalysisBatchImportService
  Error = Class.new(StandardError)

  DEFAULT_EXPORTS_DIR = Rails.root.join('storage/analysis_exports').to_s
  UPSERT_SLICE_SIZE = 1000
  RAW_DATASETS = %w[log_files log_lines round_users rounds].freeze
  SNAPSHOT_MODELS = %w[map_balance time_of_week].freeze
  IDENTITY_FIELDS = {
    'alien_strategies' => %w[round_id],
    'class_stats' => %w[user_id team class_name map_name],
    'map_balance' => %w[map_name],
    'metrics' => %w[model_name],
    'resource_spending' => %w[team category bucket_start_minutes bucket_end_minutes],
    'round_duration' => %w[bucket_start_minutes bucket_end_minutes],
    'scenario_metrics' => %w[metric kill_rate],
    'tech_metrics' => %w[kind path map],
    'time_of_week' => %w[day_of_week hour_of_day],
    'users' => %w[id]
  }.freeze

  def initialize(batch_id, exports_dir: nil)
    @batch_id = Integer(batch_id)
    @exports_dir = File.expand_path(exports_dir || ENV.fetch('ANALYSIS_EXPORTS_DIR', DEFAULT_EXPORTS_DIR))
  end

  def call
    sources = analysis_sources
    raise Error, "No recognized analysis exports found for batch #{@batch_id} under #{batch_dir}" if sources.empty?

    database = DuckDB::Database.open
    connection = database.connect
    max_id_before = AnalysisResult.maximum(:id) || 0
    imported_at = Time.current
    @source_counts = sources.to_h do |dataset, glob|
      [dataset, import_dataset(connection, dataset, glob, imported_at)]
    end
    processed = @source_counts.values.sum

    stat = ImportRowStat.measure(AnalysisResult, processed: processed, max_id_before: max_id_before)
    log_stat(stat)
    stat
  ensure
    connection&.close
    database&.close
  end

  private

  def log_stat(stat)
    Rails.logger.info("[AnalysisBatchImportService] Imported batch #{@batch_id}:")
    Rails.logger.info("[AnalysisBatchImportService]   analysis_results: #{stat}")
    @source_counts.to_h.each do |source, count|
      Rails.logger.info("[AnalysisBatchImportService]     from #{source}: #{count} rows")
    end
  end

  def import_dataset(connection, dataset, glob, imported_at)
    model = model_for(dataset)
    batch_id = snapshot_model?(model) ? AnalysisResult::CURRENT_SNAPSHOT_BATCH_ID : @batch_id
    AnalysisResult.where(batch_id: batch_id, model: model).delete_all if snapshot_model?(model)

    fields = parquet_fields(connection, glob)
    identity_fields = identity_fields_for(dataset, fields)
    validate_metadata!(model, fields)
    rows = []
    processed = 0

    connection.query("SELECT * FROM #{parquet_relation(glob)}").each do |source_row|
      digest = digest_for(model, identity_fields, fields.zip(source_row).to_h)
      fields.zip(source_row).each do |field, source_value|
        next if source_value.nil?

        rows << cell(batch_id, model, digest, field, source_value, imported_at)
        processed += 1
        flush(rows) if rows.size >= UPSERT_SLICE_SIZE
      end
    end
    flush(rows)
    processed
  end

  def analysis_sources
    return [] unless Dir.exist?(batch_dir)

    Dir.children(batch_dir).sort.filter_map do |dataset|
      next if RAW_DATASETS.include?(dataset)

      glob = existing_glob(dataset)
      [dataset, glob] if glob
    end
  end

  def parquet_fields(connection, glob)
    connection.query("DESCRIBE SELECT * FROM #{parquet_relation(glob)}").map(&:first)
  end

  def parquet_relation(glob)
    "read_parquet('#{glob.gsub("'", "''")}')"
  end

  def model_for(dataset)
    dataset.start_with?('skill_') ? dataset.delete_prefix('skill_') : dataset
  end

  def snapshot_model?(model)
    SNAPSHOT_MODELS.include?(model)
  end

  def identity_fields_for(dataset, fields)
    configured = dataset.start_with?('skill_') ? %w[user_id] : IDENTITY_FIELDS[dataset]
    configured&.all? { |field| fields.include?(field) } ? configured : fields
  end

  def digest_for(model, identity_fields, attributes)
    payload = ''.b
    append_digest_part(payload, 'analysis-result-v1')
    append_digest_part(payload, model)
    identity_fields.each do |field|
      append_digest_part(payload, field)
      append_digest_part(payload, canonical_value(attributes[field]))
    end
    Digest::SHA256.digest(payload).byteslice(0, 16)
  end

  def append_digest_part(payload, value)
    bytes = value.to_s.b
    payload << [bytes.bytesize].pack('N') << bytes
  end

  def canonical_value(value)
    case value
    when nil then "null\0"
    when Integer then "integer\0#{value}"
    when Float then "float\0#{[value].pack('G')}"
    when Numeric then "number\0#{value}"
    when Time then "time\0#{value.utc.iso8601(6)}"
    when TrueClass, FalseClass then "boolean\0#{value ? 1 : 0}"
    else "string\0#{value}"
    end
  end

  def cell(batch_id, model, digest, field, source_value, imported_at)
    value, text_value = case source_value
                        when Numeric then [source_value.to_f, nil]
                        when TrueClass then [1.0, nil]
                        when FalseClass then [0.0, nil]
                        when Time then [nil, source_value.utc.iso8601(6)]
                        else [nil, source_value.to_s]
                        end
    { batch_id: batch_id, model: model, digest: digest, field: field, value: value,
      text_value: text_value, created_at: imported_at }
  end

  def flush(rows)
    return if rows.empty?

    # rubocop:disable Rails/SkipsModelValidations -- validated Parquet output is bulk imported for performance.
    AnalysisResult.upsert_all(rows, record_timestamps: false)
    # rubocop:enable Rails/SkipsModelValidations
    rows.clear
  end

  def validate_metadata!(model, fields)
    model_limit = AnalysisResult.columns_hash.fetch('model').limit
    field_limit = AnalysisResult.columns_hash.fetch('field').limit
    raise Error, "Analysis model #{model.inspect} exceeds #{model_limit} characters" if model.length > model_limit

    fields.each do |field|
      next unless field.length > field_limit

      raise Error, "Analysis field #{field.inspect} exceeds #{field_limit} characters"
    end
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
