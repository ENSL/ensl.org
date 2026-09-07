# frozen_string_literal: true

# Per-table row tally for the parquet batch importers (see
# AnalysisBatchImportService / RoundBatchImportService), so a run reports
# what it actually changed rather than just how many rows it read.
#
# `inserted` is derived from the table's auto-increment high-water mark
# rather than from the upsert itself: MySQL's INSERT .. ON DUPLICATE KEY
# UPDATE doesn't tell Rails which rows collided, but any id above the max
# seen before the upsert can only have come from a fresh insert.
ImportRowStat = Struct.new(:processed, :inserted, keyword_init: true) do
  # Rows that collided with an existing row -- either genuinely updated or
  # re-written identically; MySQL doesn't let us tell those two apart here.
  def existing
    processed - inserted
  end

  def to_s
    "#{processed} rows (#{inserted} new, #{existing} existing)"
  end

  # Counts rows created since `max_id_before` (as returned by .maximum(:id)
  # before the upsert) and pairs that with the number of rows written.
  def self.measure(model, processed:, max_id_before:)
    return new(processed: processed, inserted: 0) if processed.zero?

    new(processed: processed, inserted: model.where(model.arel_table[:id].gt(max_id_before)).count)
  end
end
