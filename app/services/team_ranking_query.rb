# frozen_string_literal: true

# Ranks teams for one game (NS1 or NS2) off the site's own league data --
# matches, contesters and contests -- rather than the ensl_analysis exports
# that PlayerRankingQuery reads. Every finished match between two different
# teams is replayed in chronological order through OpenSkill (Plackett-Luce,
# one "player" per team) to produce a rating that, unlike the stored ladder
# score, is comparable across contests and seasons.
#
# The one column that does come from ensl_analysis is :player_skill -- the
# mean OpenSkill rating of a team's six best-rated current members. Most
# teams have too few rated members for it to mean much yet, hence
# :rated_members being reported alongside it.
class TeamRankingQuery
  DEFAULT_GAME = 'NS2'

  MIN_MATCHES_OPTIONS = [1, 5, 10, 25].freeze
  DEFAULT_MIN_MATCHES = MIN_MATCHES_OPTIONS.first

  # How many of a team's members feed into the averaged player skill column.
  PLAYER_SKILL_SQUAD_SIZE = 6

  # ensl_analysis model whose per-player 'skill' metric backs :player_skill.
  # Falls back to the legacy 'os' rows, same as the player rankings page.
  PLAYER_SKILL_MODELS = %w[os_btf os].freeze

  def self.call(game: nil, min_matches: nil)
    new(game: game, min_matches: min_matches).call
  end

  def initialize(game: nil, min_matches: nil)
    @game = self.class.normalize_game(game)
    @min_matches = self.class.normalize_min_matches(min_matches)
  end

  def self.normalize_game(value)
    Contest::GAMES.include?(value.to_s) ? value.to_s : DEFAULT_GAME
  end

  def self.normalize_min_matches(value)
    numeric = Integer(value, exception: false)
    return DEFAULT_MIN_MATCHES unless numeric && MIN_MATCHES_OPTIONS.include?(numeric)

    numeric
  end

  # Returns an array of hashes, one per team that has actually played:
  # { team:, matches:, wins:, losses:, draws:, win_ratio:, rating:, mu:,
  #   sigma:, tournament_wins:, contests:, player_skill:, rated_members: }
  def call
    return [] if contest_ids.empty?

    rate_matches!

    rows = records.values.select { |record| record[:matches] >= @min_matches }
    teams = teams_by_id(rows.map { |record| record[:team_id] })

    built_rows = rows.filter_map do |record|
      team = teams[record[:team_id]]
      next unless team

      build_row(record, team)
    end

    built_rows.sort_by { |row| -row[:rating] }
  end

  private

  def build_row(record, team)
    rating = record[:rating]
    squad = squad_skills.fetch(team.id, [])

    {
      team: team,
      matches: record[:matches],
      wins: record[:wins],
      losses: record[:losses],
      draws: record[:draws],
      win_ratio: record[:matches].positive? ? (record[:wins].to_f / record[:matches]) : nil,
      rating: rating.ordinal,
      mu: rating.mu,
      sigma: rating.sigma,
      tournament_wins: tournament_wins_by_team[team.id].to_i,
      contests: record[:contest_ids].size,
      player_skill: squad.empty? ? nil : (squad.sum / squad.size),
      rated_members: squad.size
    }
  end

  def model
    @model ||= OpenSkill::Models::PlackettLuce.new
  end

  def contest_ids
    @contest_ids ||= Contest.for_game(@game).pluck(:id)
  end

  # contester_id => team_id, for every contester in the game's contests.
  # Contesters are per-contest, so the same team has many of them.
  def team_id_by_contester_id
    @team_id_by_contester_id ||= Contester.where(contest_id: contest_ids)
                                          .where.not(team_id: nil)
                                          .pluck(:id, :team_id)
                                          .to_h
  end

  def finished_matches
    Match.where(contest_id: contest_ids)
         .where.not(contester1_id: nil)
         .where.not(contester2_id: nil)
         .where.not(score1: nil)
         .where.not(score2: nil)
         .finished
         .order(:match_time, :id)
         .pluck(:contester1_id, :contester2_id, :score1, :score2, :contest_id)
  end

  def records
    @records ||= {}
  end

  def record_for(team_id)
    records[team_id] ||= {
      team_id: team_id,
      matches: 0,
      wins: 0,
      losses: 0,
      draws: 0,
      contest_ids: Set.new,
      rating: model.create_rating
    }
  end

  # Replays every finished match in chronological order, updating both teams'
  # OpenSkill ratings and their win/loss/draw tallies as it goes.
  def rate_matches!
    return if @rated

    finished_matches.each do |contester1_id, contester2_id, score1, score2, contest_id|
      team1_id = team_id_by_contester_id[contester1_id]
      team2_id = team_id_by_contester_id[contester2_id]
      next if team1_id.nil? || team2_id.nil? || team1_id == team2_id

      apply_result(record_for(team1_id), record_for(team2_id), score1, score2, contest_id)
    end

    @rated = true
  end

  def apply_result(record1, record2, score1, score2, contest_id)
    [record1, record2].each do |record|
      record[:matches] += 1
      record[:contest_ids] << contest_id
    end

    tally_result(record1, record2, score1, score2)

    updated = model.calculate_ratings([[record1[:rating]], [record2[:rating]]], ranks: ranks_for(score1, score2))
    record1[:rating] = updated[0][0]
    record2[:rating] = updated[1][0]
  end

  # Lower rank wins; equal ranks are a draw.
  def ranks_for(score1, score2)
    return [0, 0] if score1 == score2

    score1 > score2 ? [0, 1] : [1, 0]
  end

  def tally_result(record1, record2, score1, score2)
    if score1 == score2
      record1[:draws] += 1
      record2[:draws] += 1
    elsif score1 > score2
      record1[:wins] += 1
      record2[:losses] += 1
    else
      record2[:wins] += 1
      record1[:losses] += 1
    end
  end

  # Tournament victories can only come from Contest#winner_id: a single
  # tournament runs many contests, and only the deciding one is marked, so
  # there is no way to infer them from standings.
  def tournament_wins_by_team
    @tournament_wins_by_team ||= Contester.where(id: Contest.for_game(@game).select(:winner_id))
                                          .where.not(team_id: nil)
                                          .group(:team_id)
                                          .count
  end

  def teams_by_id(team_ids)
    Team.where(id: team_ids).index_by(&:id)
  end

  # team_id => the best PLAYER_SKILL_SQUAD_SIZE member skill ratings,
  # descending. Members with no ensl_analysis rating are simply absent.
  def squad_skills
    @squad_skills ||= begin
      skills = Hash.new { |hash, key| hash[key] = [] }

      member_steamids_by_team.each do |team_id, steamids|
        rated = steamids.filter_map { |steamid| player_skills[steamid] }
        skills[team_id] = rated.max(PLAYER_SKILL_SQUAD_SIZE)
      end

      skills
    end
  end

  # Current rosters are close to useless here -- disbanded and long-finished
  # teams have moved nearly everyone to "past member" -- so the squad is
  # everyone who was ever fielded in one of the team's match lineups, plus
  # whoever is still on the roster today. Mercs are excluded: they played
  # for the team but were never part of it.
  def member_steamids_by_team
    @member_steamids_by_team ||= begin
      by_team = Hash.new { |hash, key| hash[key] = Set.new }

      (lineup_steamids + roster_steamids).each do |team_id, steamid|
        by_team[team_id] << steamid
      end

      by_team
    end
  end

  def lineup_steamids
    Matcher.joins(:contester, :user)
           .where(merc: false)
           .where(contesters: { contest_id: contest_ids })
           .where.not(users: { steamid: [nil, ''] })
           .distinct
           .pluck('contesters.team_id', 'users.steamid')
  end

  def roster_steamids
    Teamer.active
          .joins(:user)
          .where.not(users: { steamid: [nil, ''] })
          .pluck(:team_id, 'users.steamid')
  end

  # normalized steamid => latest OpenSkill skill value from ensl_analysis.
  def player_skills
    @player_skills ||= load_player_skills
  end

  def load_player_skills
    batch_id = AnalysisResult.historical.maximum(:batch_id)
    return {} unless batch_id

    by_model = Hash.new { |hash, key| hash[key] = {} }
    AnalysisResult.historical
                  .where(batch_id: batch_id, model: PLAYER_SKILL_MODELS, metric: 'skill')
                  .where.not(steamid: [AnalysisResult::NO_STEAMID, nil])
                  .pluck(:model, :steamid, :value)
                  .each do |model_name, steamid, value|
      normalized = User.normalize_steamid(steamid)
      by_model[model_name][normalized] = value if normalized
    end

    # Later models win, so the preferred model overwrites the legacy fallback.
    PLAYER_SKILL_MODELS.reverse.inject({}) { |memo, model_name| memo.merge(by_model[model_name]) }
  end
end
