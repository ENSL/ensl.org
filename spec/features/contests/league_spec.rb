require 'rails_helper'

RSpec.feature 'League contest integration', type: :feature do
  scenario 'admin creates a league, teams join, matches played and scores applied' do
    # Setup admin and sign in (UI sign-in not strictly necessary for model actions)
    admin = create(:user, :admin)
    sign_in_as(admin)

    # Create a league contest
    contest = create(:contest, contest_type: Contest::TYPE_LEAGUE, name: 'Integration League', start: 1.day.ago,
                               end: 10.days.from_now)

    # Create maps and a week for the contest using factories
    map1 = create(:map)
    map2 = create(:map)
    week = create(:week, contest: contest, name: 'Week 1', start_date: Date.today, map1: map1, map2: map2)

    # Create 4 teams with leaders and join them to the contest via factories
    teams = []
    4.times do |i|
      user = create(:user)
      team = create(:team, founder: user, name: "Team #{i + 1}")
      teams << team
      create(:contester, team: team, contest: contest)
    end

    contest.reload

    # Create round-robin matches (each pair once)
    contesters = contest.contesters.to_a
    matches = []
    contesters.combination(2) do |c1, c2|
      m = create(:match, contest: contest, contester1: c1, contester2: c2, week: week, match_time: Time.now)
      matches << m
    end

    expect(matches.size).to be >= 1

    # Generate deterministic pseudo-random results and compute expected aggregates
    rng = Random.new(20_260_121)
    expected = Hash.new { |h, k| h[k] = { score: 0, win: 0, loss: 0, draw: 0 } }

    matches.each do |m|
      s1 = rng.rand(0..5)
      s2 = rng.rand(0..5)
      m.update!(score1: s1, score2: s2)

      # Update expected aggregates
      expected[m.contester1_id][:score] += s1
      expected[m.contester2_id][:score] += s2
      if s1 == s2
        expected[m.contester1_id][:draw] += 1
        expected[m.contester2_id][:draw] += 1
      elsif s1 > s2
        expected[m.contester1_id][:win] += 1
        expected[m.contester2_id][:loss] += 1
      else
        expected[m.contester2_id][:win] += 1
        expected[m.contester1_id][:loss] += 1
      end
    end

    # Reload contesters and assert their stats match expected
    contest.contesters.each do |contester|
      contester.reload
      exp = expected[contester.id]
      expect(contester.score).to eq(exp[:score])
      expect(contester.win).to eq(exp[:win])
      expect(contester.loss).to eq(exp[:loss])
      expect(contester.draw).to eq(exp[:draw])
    end

    # All matches should be available as finished
    expect(contest.matches.finished.count).to eq(matches.count)
  end
end
