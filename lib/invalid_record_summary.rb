# frozen_string_literal: true

class InvalidRecordSummary
  def self.call(model_names: nil, limit: 20, sample_limit: 5)
    new(model_names: model_names, limit: limit, sample_limit: sample_limit).call
  end

  def initialize(model_names: nil, limit: 20, sample_limit: 5)
    @model_names = Array(model_names).flat_map { |value| value.to_s.split(',') }.map(&:strip).reject(&:empty?)
    @limit = [limit.to_i, 1].max
    @sample_limit = [sample_limit.to_i, 0].max
  end

  def call
    load_app_models!

    total_invalid_records = 0
    by_model = {}

    candidate_models.each do |model|
      invalid_records, validation_exceptions = collect_invalid_records(model)
      next if invalid_records.empty? && validation_exceptions.empty?

      breakdown = Hash.new(0)
      sample_ids = []

      invalid_records.each do |record|
        total_invalid_records += 1
        sample_ids << record.id if record.respond_to?(:id) && sample_ids.length < @sample_limit

        error_entries_for(record).each do |attribute, message|
          key = error_key(attribute, message)
          breakdown[key] += 1 if key.present?
        end
      end

      model_stats = {
        invalid_count: invalid_records.count,
        distinct_error_types: breakdown.size,
        top_errors: top_errors_for(breakdown),
        sample_ids: sample_ids
      }

      unless validation_exceptions.empty?
        model_stats[:validation_exceptions] = validation_exceptions.sort_by { |label, count| [-count, label] }
      end

      by_model[model.name] = model_stats
    end

    {
      total_invalid_records: total_invalid_records,
      model_count: by_model.size,
      by_model: by_model.sort_by { |_, stats| stats[:invalid_count] }.reverse.to_h,
      generated_at: Time.current.utc.iso8601
    }
  end

  def format(summary = call)
    lines = []
    lines << 'Database invalid record summary'
    lines << "Generated at: #{summary[:generated_at]}"
    lines << "Total invalid records: #{summary[:total_invalid_records]}"
    lines << "Models scanned: #{summary[:model_count]}"
    lines << ''

    if summary[:by_model].empty?
      lines << 'No invalid records found.'
      return lines.join("\n")
    end

    summary[:by_model].each do |model_name, stats|
      lines << "#{model_name}: invalid=#{stats[:invalid_count]}, distinct_error_types=#{stats[:distinct_error_types]}"
      stats[:top_errors].each do |entry|
        lines << "  - #{entry[:label]} (#{entry[:count]})"
      end
      if stats[:validation_exceptions].to_a.any?
        stats[:validation_exceptions].each do |label, count|
          lines << "  - validation exception: #{label} (#{count})"
        end
      end
      lines << "  sample_ids=#{stats[:sample_ids].join(', ')}" if stats[:sample_ids].any?
      lines << ''
    end

    lines.join("\n")
  end

  private

  def candidate_models
    all_models = ActiveRecord::Base.descendants
    all_models.reject! { |model| model.abstract_class? || model.name.nil? }
    all_models.select! { |model| model.respond_to?(:table_exists?) && model.table_exists? }

    if @model_names.empty?
      all_models
    else
      selected = @model_names.map do |model_name|
        model_name.safe_constantize
      end.compact
      selected.select { |model| all_models.include?(model) }
    end
  end

  def load_app_models!
    return unless defined?(Rails)

    model_glob = Rails.root.join('app/models/**/*.rb')
    Dir.glob(model_glob.to_s).sort.each do |path|
      require_dependency(path) if path.end_with?('.rb')
    rescue StandardError
      # Ignore files that are not plain model classes, such as concerns or Rails generator helpers.
    end
  end

  def collect_invalid_records(model)
    invalid_records = []
    validation_exceptions = Hash.new(0)

    begin
      model.find_each do |record|
        invalid_records << record if record.invalid?
      rescue StandardError => e
        validation_exceptions[exception_label(e)] += 1
      end
    rescue StandardError => e
      validation_exceptions["scan: #{model.name}: #{exception_label(e)}"] += 1
    end

    [invalid_records, validation_exceptions]
  end

  def error_entries_for(record)
    errors = record.errors
    payload = {}

    begin
      payload = errors.to_hash
    rescue StandardError
      begin
        payload = errors.messages || {}
      rescue StandardError
        return []
      end
    end

    return [] unless payload.is_a?(Hash)

    entries = []
    payload.each do |attribute, messages|
      values = messages.is_a?(Array) ? messages : Array(messages)
      values.each do |message|
        next if message.nil?

        entries << [attribute.to_s, message.to_s]
      end
    end
    entries
  rescue StandardError
    []
  end

  def exception_label(error)
    "#{error.class}: #{error.message}"
  end

  def error_key(attribute, message)
    attribute = attribute.to_s.strip
    message = message.to_s.strip
    return if attribute.empty? && message.empty?

    "#{attribute}: #{message}"
  end

  def top_errors_for(breakdown)
    breakdown
      .sort_by { |label, count| [-count, label] }
      .first(@limit)
      .map { |label, count| { label: label, count: count } }
  end
end
