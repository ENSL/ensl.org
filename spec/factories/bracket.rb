# frozen_string_literal: true

module BracketFactoryHelpers
  CUSTOM_TEXT_SAMPLES = [
    'Winner of Upper Bracket',
    'Winner of Lower Bracket',
    'Winner of Pool A',
    'Winner of Pool B',
    'Loser Bracket Finalist',
    'Grand Finals Winner',
    'TBD',
    'Qualifier #1',
    'Qualifier #2'
  ].freeze

  # Returns the correct row positions for bracket cells at a given column.
  # The view uses: (row % 2^(col+1)) == 2^col
  # So col 0: rows 1,3,5,7,...  col 1: rows 2,6,10,14,...  col 2: rows 4,12,20,28,...
  def self.cell_rows(col, slots)
    step = 2**(col + 1)
    offset = step / 2
    max_row = slots * 2 - 1
    rows = []
    r = offset
    while r <= max_row
      rows << r
      r += step
    end
    rows
  end

  def self.num_cols(slots)
    [(slots - 1).bit_length + 1, 2].max
  end

  # Two predecessor rows for cell at (row, col) — the cells from col-1 that feed into it
  def self.pred_rows(row, col)
    half = 2**(col - 1)
    [row - half, row + half]
  end

  # ── Normal bracket: all starters = teams, all later cells = matches, all scored ──
  def self.build_normal(bracket, teams_pool:)
    slots = bracket.slots
    contest = bracket.contest
    maps = contest.maps.to_a
    teams = teams_pool.sample([slots, teams_pool.size].min)
    cell_effective = {} # (row,col) => Contester who "won" this cell

    col0 = cell_rows(0, slots)
    col0.each_with_index do |row, idx|
      next unless teams[idx]

      c = Contester.find_by(contest: contest, team: teams[idx])
      next unless c

      FactoryBot.create(:bracketer, bracket: bracket, row: row, column: 0, team_id: c.id)
      cell_effective[[row, 0]] = c
    end

    (1...num_cols(slots)).each do |col|
      cell_rows(col, slots).each do |row|
        upper, lower = pred_rows(row, col)
        c1 = cell_effective[[upper, col - 1]]
        c2 = cell_effective[[lower, col - 1]]
        next unless c1 && c2

        match = FactoryBot.create(:match, contest: contest, contester1: c1, contester2: c2,
                                          map1: maps[0], map2: maps[1] || maps[0],
                                          match_time: rand(1..14).days.ago)
        s1 = rand(0..4)
        s2 = rand(0..4)
        s2 = (s1 == s2 ? s1 + 1 : s2) # no ties
        match.update(score1: s1, score2: s2)

        FactoryBot.create(:bracketer, bracket: bracket, row: row, column: col, match_id: match.id)
        cell_effective[[row, col]] = (s1 > s2 ? c1 : c2)
      end
    end
  end

  # ── Teams-only bracket: every cell = a team, no matches. Admin-placed results. ──
  def self.build_teams_only(bracket, teams_pool:)
    slots = bracket.slots
    contest = bracket.contest
    teams = teams_pool.sample([slots, teams_pool.size].min)
    cell_effective = {}

    col0 = cell_rows(0, slots)
    col0.each_with_index do |row, idx|
      next unless teams[idx]

      c = Contester.find_by(contest: contest, team: teams[idx])
      next unless c

      FactoryBot.create(:bracketer, bracket: bracket, row: row, column: 0, team_id: c.id)
      cell_effective[[row, 0]] = c
    end

    (1...num_cols(slots)).each do |col|
      cell_rows(col, slots).each do |row|
        upper, lower = pred_rows(row, col)
        candidates = [cell_effective[[upper, col - 1]], cell_effective[[lower, col - 1]]].compact
        next if candidates.empty?

        winner = candidates.sample
        FactoryBot.create(:bracketer, bracket: bracket, row: row, column: col, team_id: winner.id)
        cell_effective[[row, col]] = winner
      end
    end
  end

  # ── Mixed bracket: asymmetry, some custom text starters, some unplayed, no orphans ──
  def self.build_mixed(bracket, teams_pool:)
    slots = bracket.slots
    contest = bracket.contest
    maps = contest.maps.to_a
    cell_effective = {} # (row,col) => Contester or nil
    cell_is_text = {}   # track text cells to avoid advancing orphans

    col0 = cell_rows(0, slots)
    # Fill most with teams, a few with custom text
    teams = teams_pool.sample([slots, teams_pool.size].min)
    text_count = [rand(2..4), slots / 4].min
    text_indices = (0...slots).to_a.sample(text_count)

    team_idx = 0
    col0.each_with_index do |row, idx|
      if text_indices.include?(idx)
        FactoryBot.create(:bracketer, bracket: bracket, row: row, column: 0,
                                      custom_text: CUSTOM_TEXT_SAMPLES.sample)
        cell_is_text[[row, 0]] = true
      else
        next unless teams[team_idx]

        c = Contester.find_by(contest: contest, team: teams[team_idx])
        team_idx += 1
        next unless c

        FactoryBot.create(:bracketer, bracket: bracket, row: row, column: 0, team_id: c.id)
        cell_effective[[row, 0]] = c
      end
    end

    # Disable a chunk of one side to create asymmetry
    disable_start = rand(0...(slots / 2)) # pick a starting index in the lower half
    disable_count = rand(2..([4, slots / 4].min))
    disabled_rows = col0[disable_start, disable_count] || []
    disabled_rows.each do |row|
      # Only disable if nothing important is there; overwrite the existing bracketer
      existing = bracket.bracketers.pos(row, 0).first
      if existing
        existing.update(team_id: nil, match_id: nil, custom_text: nil, disabled: true)
        cell_effective.delete([row, 0])
        cell_is_text.delete([row, 0])
      else
        FactoryBot.create(:bracketer, bracket: bracket, row: row, column: 0, disabled: true)
      end
    end

    # Build subsequent columns
    (1...num_cols(slots)).each do |col|
      cell_rows(col, slots).each do |row|
        upper, lower = pred_rows(row, col)
        c1 = cell_effective[[upper, col - 1]]
        c2 = cell_effective[[lower, col - 1]]
        upper_text = cell_is_text[[upper, col - 1]]
        lower_text = cell_is_text[[lower, col - 1]]

        if c1 && c2
          # Both real: create match (some played, some not)
          match = FactoryBot.create(:match, contest: contest, contester1: c1, contester2: c2,
                                            map1: maps[0], map2: maps[1] || maps[0],
                                            match_time: rand(-3..5).days.from_now)
          if rand < 0.6 # 60% played
            s1 = rand(0..4)
            s2 = rand(0..4)
            s2 = (s1 == s2 ? s1 + 1 : s2)
            match.update(score1: s1, score2: s2)
            winner = s1 > s2 ? c1 : c2
            cell_effective[[row, col]] = winner
          end
          FactoryBot.create(:bracketer, bracket: bracket, row: row, column: col, match_id: match.id)
        elsif c1 && !c2 && !lower_text
          # Only upper has a real team, lower is empty/disabled: team advances
          FactoryBot.create(:bracketer, bracket: bracket, row: row, column: col, team_id: c1.id)
          cell_effective[[row, col]] = c1
        elsif c2 && !c1 && !upper_text
          FactoryBot.create(:bracketer, bracket: bracket, row: row, column: col, team_id: c2.id)
          cell_effective[[row, col]] = c2
        end
        # If both are text/nil/disabled — cell stays empty (no orphan advancement)
      end
    end
  end

  # ── Wild west bracket: anything goes. Orphans, empty, mis-matched, etc. ──
  def self.build_wild_west(bracket, _teams_pool:)
    slots = bracket.slots
    contest = bracket.contest
    maps = contest.maps.to_a
    all_contesters = contest.contesters.to_a

    total_cols = num_cols(slots)
    (0...total_cols).each do |col|
      cell_rows(col, slots).each do |row|
        roll = rand(100)
        if roll < 10
          # Empty — do nothing
        elsif roll < 20
          FactoryBot.create(:bracketer, bracket: bracket, row: row, column: col, disabled: true)
        elsif roll < 35
          FactoryBot.create(:bracketer, bracket: bracket, row: row, column: col,
                                        custom_text: CUSTOM_TEXT_SAMPLES.sample)
        elsif roll < 55
          c = all_contesters.sample
          FactoryBot.create(:bracketer, bracket: bracket, row: row, column: col, team_id: c&.id) if c
        else
          # Match with random contesters (may not match predecessors at all)
          c1, c2 = all_contesters.sample(2)
          next unless c1 && c2

          match = FactoryBot.create(:match, contest: contest, contester1: c1, contester2: c2,
                                            map1: maps[0], map2: maps[1] || maps[0],
                                            match_time: rand(-7..7).days.from_now)
          if rand < 0.5
            s1 = rand(0..5)
            s2 = rand(0..5)
            match.update(score1: s1, score2: s2)
          end
          FactoryBot.create(:bracketer, bracket: bracket, row: row, column: col, match_id: match.id)
        end
      end
    end
  end
end

FactoryBot.define do
  factory :bracket do
    contest
    sequence(:name) { |n| "Bracket #{n}" }
    slots { 16 }

    trait :normal do
      transient do
        teams_pool { [] }
      end
      after(:create) do |bracket, evaluator|
        BracketFactoryHelpers.build_normal(bracket, teams_pool: evaluator.teams_pool)
      end
    end

    trait :teams_only do
      transient do
        teams_pool { [] }
      end
      after(:create) do |bracket, evaluator|
        BracketFactoryHelpers.build_teams_only(bracket, teams_pool: evaluator.teams_pool)
      end
    end

    trait :mixed do
      transient do
        teams_pool { [] }
      end
      after(:create) do |bracket, evaluator|
        BracketFactoryHelpers.build_mixed(bracket, teams_pool: evaluator.teams_pool)
      end
    end

    trait :wild_west do
      transient do
        teams_pool { [] }
      end
      after(:create) do |bracket, evaluator|
        BracketFactoryHelpers.build_wild_west(bracket, _teams_pool: evaluator.teams_pool)
      end
    end
  end
end
