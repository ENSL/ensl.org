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
  MIN_GAMES_OPTIONS = [5, 10, 25, 50].freeze
  DEFAULT_MIN_GAMES = 25

  def self.call(game: 'NS1', min_games: nil)
    new(game: game, min_games: min_games).call
  end

  def initialize(game: 'NS1', min_games: nil)
    @game = game
    @min_games = normalize_min_games(min_games)
  end

  # Returns an array of hashes with pick-order stats + a dedicated OpenSkill
  # score replayed only from gather draft order (not match outcomes).
  # Rows are sorted by best (highest) pick-order OpenSkill score first.
  def call
    replay_pick_orders!

    users_by_id = User.where(id: records.keys).index_by(&:id)

    rows = records.filter_map do |user_id, record|
      next if record[:pick_games_count].zero?
      next if record[:games_count] < @min_games

      user = users_by_id[user_id]
      next unless user

      {
        user: user,
        average_pick_order: record[:pick_total] / record[:pick_games_count],
        games_count: record[:games_count],
        captain_percentage: (record[:captain_games_count].to_f / record[:games_count]) * 100,
        pick_openskill: record[:rating].ordinal
      }
    end

    rows.sort_by do |row|
      [-row[:pick_openskill], -row[:games_count], row[:average_pick_order], row[:user].to_s.downcase]
    end
  end

  private

  def model
    @model ||= OpenSkill::Models::PlackettLuce.new
  end

  # Gatherer rows that were actually drafted onto a team.
  def played_gatherers_scope
    Gatherer
      .joins(:gather)
      .joins('INNER JOIN categories ON categories.id = gathers.category_id')
      .where(categories: { name: @game, domain: Category::DOMAIN_GAMES })
      .where.not(gatherers: { pick_order: nil })
      .where.not(gatherers: { user_id: nil })
  end

  def game_rows
    @game_rows ||= played_gatherers_scope
                   .order('gathers.id ASC', 'gatherers.pick_order ASC', 'gatherers.id ASC')
                   .pluck(
                     'gathers.id',
                     'gatherers.user_id',
                     'gatherers.pick_order',
                     Arel.sql(
                       'CASE WHEN gatherers.id = COALESCE(gathers.captain1_id, 0) OR ' \
                       'gatherers.id = COALESCE(gathers.captain2_id, 0) THEN 1 ELSE 0 END'
                     )
                   )
  end

  def records
    @records ||= {}
  end

  def record_for(user_id)
    records[user_id] ||= {
      rating: model.create_rating,
      games_count: 0,
      captain_games_count: 0,
      pick_games_count: 0,
      pick_total: 0.0
    }
  end

  def replay_pick_orders!
    return if @replayed

    current_gather_id = nil
    gather_picks = []

    game_rows.each do |gather_id, user_id, pick_order, captain_flag|
      if current_gather_id && gather_id != current_gather_id
        apply_gather_ratings!(gather_picks)
        gather_picks = []
      end

      current_gather_id = gather_id
      record = record_for(user_id)
      record[:games_count] += 1
      record[:captain_games_count] += 1 if captain_flag.to_i == 1
      next if captain_flag.to_i == 1

      record[:pick_games_count] += 1
      record[:pick_total] += pick_order.to_f
      gather_picks << [user_id, pick_order.to_i]
    end

    apply_gather_ratings!(gather_picks)
    @replayed = true
  end

  def apply_gather_ratings!(gather_picks)
    return if gather_picks.size < 2

    pick_orders = gather_picks.map(&:last)
    rank_for_pick = {}
    pick_orders.uniq.sort.each_with_index { |pick_order, rank| rank_for_pick[pick_order] = rank }
    ranks = pick_orders.map { |pick_order| rank_for_pick[pick_order] }

    participants = gather_picks.map { |user_id, _pick_order| [record_for(user_id)[:rating]] }
    updated = model.calculate_ratings(participants, ranks: ranks)

    gather_picks.each_with_index do |(user_id, _pick_order), index|
      record_for(user_id)[:rating] = updated[index][0]
    end
  end

  def normalize_min_games(value)
    return DEFAULT_MIN_GAMES if value.nil?

    numeric = Integer(value, exception: false)
    return DEFAULT_MIN_GAMES unless numeric
    return DEFAULT_MIN_GAMES unless MIN_GAMES_OPTIONS.include?(numeric)

    numeric
  end
end
