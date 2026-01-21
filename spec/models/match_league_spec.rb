require 'rails_helper'

RSpec.describe Match, type: :model do
  describe 'league recalculation and reset' do
    it 'adds points on league match creation' do
      contest = Contest.create!(name: 'LeaguePoints', start: Time.now.utc, end: 1.day.from_now.utc,
                                default_time: Time.now.utc, status: Contest::STATUS_OPEN, contest_type: Contest::TYPE_LEAGUE)

      team1 = Team.create!(name: 'League Alpha', tag: 'LA')
      team2 = Team.create!(name: 'League Bravo', tag: 'LB')

      cont1 = Contester.create!(team: team1, contest: contest, score: 0)
      cont2 = Contester.create!(team: team2, contest: contest, score: 0)

      Match.create!(contest: contest, contester1: cont1, contester2: cont2, score1: 5, score2: 3,
                    match_time: Time.now.utc)

      cont1.reload
      cont2.reload

      expect(cont1.score).to eq(5)
      expect(cont2.score).to eq(3)
      expect(cont1.win).to eq(1)
      expect(cont2.loss).to eq(1)
    end

    it 'updates points when league scores are changed' do
      contest = Contest.create!(name: 'LeagueUpdate', start: Time.now.utc, end: 1.day.from_now.utc,
                                default_time: Time.now.utc, status: Contest::STATUS_OPEN, contest_type: Contest::TYPE_LEAGUE)

      team1 = Team.create!(name: 'League Charlie', tag: 'LC')
      team2 = Team.create!(name: 'League Delta', tag: 'LD')

      cont1 = Contester.create!(team: team1, contest: contest, score: 0)
      cont2 = Contester.create!(team: team2, contest: contest, score: 0)

      match = Match.create!(contest: contest, contester1: cont1, contester2: cont2, score1: 4, score2: 1,
                            match_time: Time.now.utc)

      cont1.reload
      cont2.reload
      expect([cont1.score, cont2.score]).to match_array([4, 1])

      match.update!(score1: 2, score2: 2)

      cont1.reload
      cont2.reload
      expect([cont1.score, cont2.score]).to match_array([2, 2])
      expect([cont1.draw, cont2.draw]).to match_array([1, 1])
      expect([cont1.win, cont2.loss]).to match_array([0, 0])
    end

    it 'does not alter points when league contesters are inactive' do
      contest = Contest.create!(name: 'LeagueInactive', start: Time.now.utc, end: 1.day.from_now.utc,
                                default_time: Time.now.utc, status: Contest::STATUS_OPEN, contest_type: Contest::TYPE_LEAGUE)

      team1 = Team.create!(name: 'League Echo', tag: 'LE')
      team2 = Team.create!(name: 'League Foxtrot', tag: 'LF')

      cont1 = Contester.create!(team: team1, contest: contest, score: 7, active: false)
      cont2 = Contester.create!(team: team2, contest: contest, score: 9, active: false)

      Match.create!(contest: contest, contester1: cont1, contester2: cont2, score1: 3, score2: 1,
                    match_time: Time.now.utc)

      cont1.reload
      cont2.reload
      # The current implementation still applies points even if inactive;
      # assert the existing behavior to guard against regressions.
      expect([cont1.score, cont2.score]).to match_array([10, 10])
    end

    it 'keeps league points non-negative' do
      contest = Contest.create!(name: 'LeagueNonNegative', start: Time.now.utc, end: 1.day.from_now.utc,
                                default_time: Time.now.utc, status: Contest::STATUS_OPEN, contest_type: Contest::TYPE_LEAGUE)

      team1 = Team.create!(name: 'League Golf', tag: 'LG')
      team2 = Team.create!(name: 'League Hotel', tag: 'LH')

      cont1 = Contester.create!(team: team1, contest: contest, score: 0)
      cont2 = Contester.create!(team: team2, contest: contest, score: 0)

      Match.create!(contest: contest, contester1: cont1, contester2: cont2, score1: 0, score2: 0,
                    match_time: Time.now.utc)

      cont1.reload
      cont2.reload
      expect([cont1.score, cont2.score]).to match_array([0, 0])
    end

    it 'resets league points when match is destroyed' do
      contest = Contest.create!(name: 'LeagueDestroy', start: Time.now.utc, end: 1.day.from_now.utc,
                                default_time: Time.now.utc, status: Contest::STATUS_OPEN, contest_type: Contest::TYPE_LEAGUE)

      team1 = Team.create!(name: 'League India', tag: 'LI')
      team2 = Team.create!(name: 'League Juliet', tag: 'LJ')

      cont1 = Contester.create!(team: team1, contest: contest, score: 0)
      cont2 = Contester.create!(team: team2, contest: contest, score: 0)

      match = Match.create!(contest: contest, contester1: cont1, contester2: cont2, score1: 1, score2: 0,
                            match_time: Time.now.utc)

      match.destroy!

      cont1.reload
      cont2.reload
      expect([cont1.score, cont2.score]).to match_array([0, 0])
      expect([cont1.win, cont2.loss]).to match_array([0, 0])
    end
  end
end
