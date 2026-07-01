# frozen_string_literal: true

FactoryBot.define do
  factory :contest do
    sequence(:name) { |n| "Contest ##{n}" }
    start { 1.day.ago }
    add_attribute(:end) { 10.days.from_now }
    status { Contest::STATUS_OPEN }
    default_time { '12:00:00' }

    trait :bracket do
      contest_type { Contest::TYPE_BRACKET }
    end

    trait :league do
      contest_type { Contest::TYPE_LEAGUE }
    end

    trait :with_teams do
      transient do
        teams_count { 4 }
      end

      after(:create) do |contest, evaluator|
        create_list(:contester, evaluator.teams_count, contest: contest)
      end
    end

    trait :with_maps do
      transient do
        maps_count { 2 }
      end

      after(:create) do |contest, evaluator|
        maps = create_list(:map, evaluator.maps_count)
        contest.maps << maps
      end
    end

    trait :with_scored_matches do
      transient do
        matches_count { 50 }
      end

      after(:create) do |contest, evaluator|
        contesters = contest.contesters.to_a
        maps = contest.maps.to_a

        evaluator.matches_count.times do |i|
          # Pick two different contesters
          cont1, cont2 = contesters.sample(2)

          create(:match,
                 contest: contest,
                 contester1: cont1,
                 contester2: cont2,
                 map1: maps.sample,
                 map2: maps.sample,
                 match_time: Time.current - (i * 2).hours,
                 score1: rand(1..4),
                 score2: rand(1..4))
        end
      end
    end

    trait :bracket_ready do
      contest_type { Contest::TYPE_BRACKET }

      transient do
        teams_count { 4 }
        maps_count { 2 }
      end

      after(:create) do |contest, evaluator|
        create_list(:contester, evaluator.teams_count, contest: contest)
        maps = create_list(:map, evaluator.maps_count)
        contest.maps << maps
      end
    end

    trait :tournament do
      contest_type { Contest::TYPE_BRACKET }

      after(:create) do |contest|
        # Create 8 teams as contesters
        teams = create_list(:team, 8)
        contesters = teams.map { |team| create(:contester, contest: contest, team: team) }

        # Add 2 maps
        maps = create_list(:map, 2)
        contest.maps << maps

        # Create 7 matches (representing a tournament tree: 4 first-round + 2 semi-finals + 1 final)
        rng = Random.new(20_260_209)
        (0..6).each do |i|
          create(
            :match,
            contest: contest,
            contester1: contesters[i % contesters.size],
            contester2: contesters[(i + 1) % contesters.size],
            map1: maps[0],
            map2: maps[1],
            score1: rng.rand(2..5),
            score2: rng.rand(0..3),
            match_time: (3 - (i / 3)).days.ago
          )
        end
      end
    end

    trait :with_bracket do
      contest_type { Contest::TYPE_BRACKET }

      transient do
        bracket_name { 'Main Bracket' }
        bracket_slots { 8 }
        teams_count { 0 }
        maps_count { 2 }
      end

      after(:create) do |contest, evaluator|
        # Create bracket
        create(:bracket, contest: contest, name: evaluator.bracket_name, slots: evaluator.bracket_slots)

        # Create maps if specified
        if evaluator.maps_count.positive?
          maps = create_list(:map, evaluator.maps_count)
          contest.maps << maps
        end

        # Create teams with members if specified
        if evaluator.teams_count.positive?
          create_list(:team, evaluator.teams_count, :with_members)
            .each do |team|
            create(:contester, contest: contest, team: team)
          end
        end
      end
    end

    trait :randomized_bracket_contest do
      contest_type { Contest::TYPE_BRACKET }

      transient do
        min_teams { 20 }
        max_teams { 30 }
        min_team_members { 6 }
        max_team_members { 15 }
      end

      after(:create) do |contest, evaluator|
        # Create teams with members
        teams_count = rand(evaluator.min_teams..evaluator.max_teams)
        teams = []
        teams_count.times do |i|
          members_count = rand(evaluator.min_team_members..evaluator.max_team_members)
          team = create(:team, :with_members, name: "Team #{contest.id}-#{i}", members_count: members_count)
          create(:contester, contest: contest, team: team)
          teams << team
        end

        # Create maps
        maps = create_list(:map, rand(2..3))
        contest.maps << maps

        # Predefined bracket configs exploring many scenarios
        bracket_configs = [
          # Normal fully-played brackets of various sizes
          { name: 'Grand Final (16)',     trait: :normal,     slots: 16 },
          { name: 'Winners Bracket (8)',  trait: :normal,     slots: 8 },
          { name: 'Losers Bracket (4)',   trait: :normal,     slots: 4 },
          { name: 'Showmatch (2)',        trait: :normal,     slots: 2 },
          # Teams-only bracket (admin-placed results, no matches)
          { name: 'Group Stage Results',  trait: :teams_only, slots: 8 },
          # Mixed realism: asymmetry, some unplayed, custom text, no orphans
          { name: 'Mixed Bracket',        trait: :mixed,      slots: 16 },
          # Wild west: anything goes
          { name: 'Wild West Bracket',    trait: :wild_west,  slots: 16 }
        ]

        bracket_configs.each do |config|
          create(:bracket, config[:trait],
                 contest: contest,
                 name: config[:name],
                 slots: config[:slots],
                 teams_pool: teams)
        end
      end
    end

    trait :front_page_dataset do
      contest_type { Contest::TYPE_BRACKET }

      transient do
        author { create(:user) }
        teams_count { 1000 }
        contesters_count { 2000 }
        matches_count { 1800 }
        now { Time.current }
      end

      after(:create) do |contest, evaluator|
        teams = create_list(:team, evaluator.teams_count, founder: evaluator.author)
        next if teams.length < 2

        contester_rows = teams.first(evaluator.contesters_count).each_with_index.map do |team, index|
          {
            team_id: team.id,
            contest_id: contest.id,
            score: index,
            extra: 0,
            trend: Contester::TREND_FLAT,
            created_at: evaluator.now,
            updated_at: evaluator.now
          }
        end
        Contester.insert_all!(contester_rows) if contester_rows.any?

        contester_ids = Contester.where(contest_id: contest.id).order(id: :desc).pluck(:id)
        next if contester_ids.length < 2

        max_matches = [evaluator.matches_count, contester_ids.length - 1].min
        match_rows = Array.new(max_matches) do |index|
          {
            contest_id: contest.id,
            contester1_id: contester_ids[index],
            contester2_id: contester_ids[index + 1],
            score1: index % 2,
            score2: (index + 1) % 2,
            match_time: evaluator.now,
            created_at: evaluator.now,
            updated_at: evaluator.now
          }
        end
        Match.insert_all!(match_rows) if match_rows.any?
      end
    end
  end
end
