# frozen_string_literal: true

# Renders a client-side sortable HTML table (see
# app/javascript/controllers/sortable_table.js). Every analysis listing
# (player rankings, and future ones like map balance) shares this instead of
# hand-rolling its own <table> markup, so adding a new listing is just a
# columns/rows definition + this one call.
module AnalysisHelper
  # columns: array of hashes, each with:
  #   key         - symbol used to look up the raw value in each row hash
  #   label       - column header text
  #   type        - :string (default) or :number; controls sort comparison
  #   tooltip     - optional plain-text explanation shown when hovering the header
  #   sort_value  - optional proc(raw_value) -> comparable value (defaults to raw_value)
  #   format      - optional proc(raw_value) -> displayed value (defaults to raw_value)
  # rows: array of hashes, each keyed by every column's :key
  def sortable_table(columns:, rows:, id: nil)
    render partial: 'analysis/sortable_table', locals: { columns: columns, rows: rows, id: id }
  end
end
