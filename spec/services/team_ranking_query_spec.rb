# frozen_string_literal: true

require 'rails_helper'

describe TeamRankingQuery do
  # Contests are split into games by name and id (see Contest.for_game), so
  # pin the ids either side of the NS1/NS2 boundary rather than relying on
  # wherever the table's auto-increment happens to sit.
  def ns1_contest(id: 1, **attrs)
    create(:contest, id: id, name: "S#{id}: Division 1", **attrs)
  end

  def ns2_contest(**attrs)
    create(:contest, id: [Contest.maximum(:id).to_i, Contest::NS2_FIRST_CONTEST_ID].max + 1, **attrs)
  end

  def played(contest, contester1, contester2, score1, score2, match_time)
    create(:match, contest: contest, contester1: contester1, contester2: contester2,
                   match_time: match_time).update!(score1: score1, score2: score2)
  end

  describe '#call' do
    it 'returns an empty array when the game has no contests' do
      expect(described_class.call(game: 'NS2')).to eq([])
    end

    it 'reports records, ratings and contest counts for teams that played' do
      contest = ns2_contest
      winner = create(:contester, contest: contest)
      loser = create(:contester, contest: contest)

      played(contest, winner, loser, 4, 0, 3.days.ago)
      played(contest, loser, winner, 1, 3, 2.days.ago)
      played(contest, winner, loser, 2, 2, 1.day.ago)

      rankings = described_class.call(game: 'NS2').index_by { |row| row[:team] }

      expect(rankings.size).to eq(2)
      expect(rankings[winner.team]).to include(matches: 3, wins: 2, losses: 0, draws: 1, contests: 1)
      expect(rankings[loser.team]).to include(matches: 3, wins: 0, losses: 2, draws: 1)
      expect(rankings[winner.team][:win_ratio]).to be_within(0.001).of(2.0 / 3)
      expect(rankings[winner.team][:rating]).to be > rankings[loser.team][:rating]
    end

    it 'ignores teams with no finished matches' do
      contest = ns2_contest
      contester1 = create(:contester, contest: contest)
      contester2 = create(:contester, contest: contest)
      create(:contester, contest: contest)

      played(contest, contester1, contester2, 3, 1, 1.day.ago)

      expect(described_class.call(game: 'NS2').map { |row| row[:team] })
        .to contain_exactly(contester1.team, contester2.team)
    end

    it 'keeps NS1 and NS2 results apart' do
      ns1 = ns1_contest
      ns2 = ns2_contest
      ns1_pair = create_list(:contester, 2, contest: ns1)
      ns2_pair = create_list(:contester, 2, contest: ns2)

      played(ns1, ns1_pair[0], ns1_pair[1], 3, 1, 1.day.ago)
      played(ns2, ns2_pair[0], ns2_pair[1], 3, 1, 1.day.ago)

      expect(described_class.call(game: 'NS1').map { |row| row[:team] })
        .to contain_exactly(ns1_pair[0].team, ns1_pair[1].team)
      expect(described_class.call(game: 'NS2').map { |row| row[:team] })
        .to contain_exactly(ns2_pair[0].team, ns2_pair[1].team)
    end

    it 'counts only contests an admin has marked a winner for' do
      won = ns2_contest
      unmarked = ns2_contest
      champion = create(:contester, contest: won)
      runner_up = create(:contester, contest: won)
      played(won, champion, runner_up, 3, 1, 1.day.ago)
      won.update!(winner: champion)

      also_champion = create(:contester, contest: unmarked, team: champion.team)
      other = create(:contester, contest: unmarked)
      played(unmarked, also_champion, other, 3, 1, 1.day.ago)

      rankings = described_class.call(game: 'NS2').index_by { |row| row[:team] }

      expect(rankings[champion.team]).to include(tournament_wins: 1, contests: 2)
      expect(rankings[runner_up.team][:tournament_wins]).to eq(0)
    end

    it 'averages the OpenSkill ratings of the six best-rated current members' do
      contest = ns2_contest
      rated = create(:contester, contest: contest)
      unrated = create(:contester, contest: contest)
      played(contest, rated, unrated, 3, 1, 1.day.ago)

      # Seven rated members: only the top six should count.
      skills = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0]
      skills.each_with_index do |skill, index|
        user = create(:user, steamid: "0:1:#{1000 + index}")
        create(:teamer, team: rated.team, user: user, rank: Teamer::RANK_MEMBER)
        create(:analysis_result, batch_id: 3, steamid: user.steamid, model: 'os_btf', metric: 'skill', value: skill)
      end

      row = described_class.call(game: 'NS2').find { |candidate| candidate[:team] == rated.team }

      expect(row[:rated_members]).to eq(described_class::PLAYER_SKILL_SQUAD_SIZE)
      expect(row[:player_skill]).to be_within(0.001).of(skills.last(6).sum / 6.0)
    end

    it 'leaves player skill blank for teams with no rated members' do
      contest = ns2_contest
      contester1 = create(:contester, contest: contest)
      contester2 = create(:contester, contest: contest)
      played(contest, contester1, contester2, 3, 1, 1.day.ago)

      row = described_class.call(game: 'NS2').first

      expect(row[:player_skill]).to be_nil
      expect(row[:rated_members]).to eq(0)
    end

    it 'counts players who were fielded for the team but have since left it' do
      contest = ns2_contest
      contester = create(:contester, contest: contest)
      opponent = create(:contester, contest: contest)
      match = create(:match, contest: contest, contester1: contester, contester2: opponent,
                             match_time: 1.day.ago)
      match.update!(score1: 3, score2: 1)

      departed = create(:user, steamid: '0:1:4242')
      create(:teamer, team: contester.team, user: departed, rank: Teamer::RANK_REMOVED)
      Matcher.create!(match: match, user: departed, contester: contester, merc: false)
      create(:analysis_result, batch_id: 4, steamid: departed.steamid, model: 'os_btf', metric: 'skill', value: 9.0)

      row = described_class.call(game: 'NS2').find { |candidate| candidate[:team] == contester.team }

      expect(row[:rated_members]).to eq(1)
      expect(row[:player_skill]).to be_within(0.001).of(9.0)
    end

    it 'ignores mercs who were only borrowed for a match' do
      contest = ns2_contest
      contester = create(:contester, contest: contest)
      opponent = create(:contester, contest: contest)
      match = create(:match, contest: contest, contester1: contester, contester2: opponent,
                             match_time: 1.day.ago)
      match.update!(score1: 3, score2: 1)

      merc = create(:user, steamid: '0:1:5252')
      Matcher.create!(match: match, user: merc, contester: contester, merc: true)
      create(:analysis_result, batch_id: 4, steamid: merc.steamid, model: 'os_btf', metric: 'skill', value: 9.0)

      row = described_class.call(game: 'NS2').find { |candidate| candidate[:team] == contester.team }

      expect(row[:rated_members]).to eq(0)
      expect(row[:player_skill]).to be_nil
    end

    it 'applies the minimum matches cutoff' do
      contest = ns2_contest
      busy1 = create(:contester, contest: contest)
      busy2 = create(:contester, contest: contest)
      quiet1 = create(:contester, contest: contest)
      quiet2 = create(:contester, contest: contest)

      5.times { |n| played(contest, busy1, busy2, 3, 1, (10 - n).days.ago) }
      played(contest, quiet1, quiet2, 3, 1, 1.day.ago)

      teams = described_class.call(game: 'NS2', min_matches: 5).map { |row| row[:team] }

      expect(teams).to contain_exactly(busy1.team, busy2.team)
    end
  end

  describe '.normalize_game' do
    it 'falls back to the default for unknown games' do
      expect(described_class.normalize_game('NS3')).to eq(described_class::DEFAULT_GAME)
      expect(described_class.normalize_game('NS1')).to eq('NS1')
    end
  end

  describe '.normalize_min_matches' do
    it 'falls back to the default for unsupported values' do
      expect(described_class.normalize_min_matches('7')).to eq(described_class::DEFAULT_MIN_MATCHES)
      expect(described_class.normalize_min_matches('10')).to eq(10)
    end
  end
end
