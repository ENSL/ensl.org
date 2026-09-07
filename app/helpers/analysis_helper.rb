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

  # Renders a MarineTechPathQuery path (raw `research_*` keys) as an arrow-
  # separated chain of icon + display name, reusing the same lookup tables
  # the round timeline built up from real log samples.
  def tech_path_display(path)
    steps = path.map do |research|
      icon = RoundsHelper::ROUND_TIMELINE_ICON_NAMES[research]
      image = image_tag("/images/ns1/#{icon}.gif", class: 'round-timeline-icon', alt: '') if icon
      tag.span(safe_join([image, tech_path_research_name(research)].compact), class: 'tech-path-step')
    end
    safe_join(steps, tag.span(' → ', class: 'tech-path-arrow'))
  end

  def tech_path_research_name(research)
    RoundsHelper::ROUND_TIMELINE_RESEARCH_NAMES[research] || research.to_s.sub(/\Aresearch_/, '').humanize
  end

  # Plain-text version of the same path, used as the client-side sort key.
  def tech_path_label(path)
    path.map { |research| tech_path_research_name(research) }.join(' > ')
  end
end
