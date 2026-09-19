# frozen_string_literal: true

# Builds the filtered, paginated collection and select options for the round
# archive. Filtering predicates remain on Round; this object coordinates the
# joins required by the selected filters.
class RoundArchiveQuery
  Result = Struct.new(:filters, :maps, :servers, :rounds, keyword_init: true)

  def self.call(filters:, page:)
    new(filters: filters, page: page).call
  end

  def initialize(filters:, page:)
    @filters = filters
    @page = page
  end

  def call
    Result.new(
      filters: @filters,
      maps: Round.present_map_names,
      servers: Round.present_server_names,
      rounds: filtered_rounds.preload(:rounders).chronologically.paginate(page: @page, per_page: 50)
    )
  end

  private

  def filtered_rounds
    scope = Round.filtered(@filters)
    scope = scope.with_players_and_users if @filters[:steamid].present? || @filters[:username].present?
    scope = scope.with_log_lines if @filters[:nickname].present?
    scope
  end
end
