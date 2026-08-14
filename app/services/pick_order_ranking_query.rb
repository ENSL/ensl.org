# frozen_string_literal: true

# Ranks players by how early they get picked during NS1 gather team
# selection (lower average `gatherers.pick_order` = picked sooner = ranked
# higher). Captain rows are excluded from the average: captains aren't
# skill-picked, they're voted in, so their own pick_order (always 1 or 2)
# would otherwise misrepresent how fast a player normally gets picked. This
# only affects what counts *towards* a player's average -- it never removes
# a player from the rankings, including when they were picked as a captain
# themselves in other gathers.
#
# Doesn't use AnalysisResult / the ensl_analysis pipeline at all; everything
# comes straight from the gathers/gatherers tables.
class PickOrderRankingQuery
  MIN_PICKS_OPTIONS = [1, 5, 10, 20].freeze
  DEFAULT_MIN_PICKS = MIN_PICKS_OPTIONS.first

  def self.call(game: 'NS1', min_picks: nil)
    new(game: game, min_picks: min_picks).call
  end

  def initialize(game: 'NS1', min_picks: nil)
    @game = game
    @min_picks = normalize_min_picks(min_picks)
  end

  # Returns an array of hashes: { user:, average_pick_order:, picks_count: },
  # sorted from fastest (lowest average pick_order) to slowest picked.
  def call
    users_by_id = User.where(id: aggregated_rows.map(&:user_id)).index_by(&:id)

    rows = aggregated_rows.filter_map do |row|
      next if @min_picks && row.picks_count.to_i < @min_picks

      user = users_by_id[row.user_id]
      next unless user

      {
        user: user,
        average_pick_order: row.average_pick_order.to_f,
        picks_count: row.picks_count.to_i
      }
    end
    rows.sort_by { |row| row[:average_pick_order] }
  end

  private

  def aggregated_rows
    @aggregated_rows ||= picked_gatherers
                         .group(:user_id)
                         .select(
                           'gatherers.user_id AS user_id',
                           'AVG(gatherers.pick_order) AS average_pick_order',
                           'COUNT(*) AS picks_count'
                         )
  end

  # Non-captain gatherer rows that were actually drafted onto a team, for
  # the given game's finished/in-progress gathers.
  def picked_gatherers
    Gatherer
      .joins(:gather)
      .joins('INNER JOIN categories ON categories.id = gathers.category_id')
      .where(categories: { name: @game, domain: Category::DOMAIN_GAMES })
      .where.not(gatherers: { pick_order: nil })
      .where.not(gatherers: { user_id: nil })
      .where('gatherers.id != COALESCE(gathers.captain1_id, 0)')
      .where('gatherers.id != COALESCE(gathers.captain2_id, 0)')
  end

  def normalize_min_picks(value)
    return nil if value.nil?

    numeric = Integer(value, exception: false)
    return DEFAULT_MIN_PICKS unless numeric
    return DEFAULT_MIN_PICKS unless MIN_PICKS_OPTIONS.include?(numeric)

    numeric
  end
end
