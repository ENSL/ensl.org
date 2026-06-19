# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Match, type: :model do
  describe 'ladder recalculation and reset' do
    it 'recomputes ladder ranks when a ladder match is changed' do
      contest = Contest.create!(name: 'LadderTest', start: Time.now.utc, end: 1.day.from_now.utc,
                                default_time: Time.now.utc, status: Contest::STATUS_OPEN, contest_type: Contest::TYPE_LADDER)

      team1 = Team.create!(name: 'Team One', tag: 'T1')
      team2 = Team.create!(name: 'Team Two', tag: 'T2')

      cont1 = Contester.create!(team: team1, contest: contest, score: 1)
      cont2 = Contester.create!(team: team2, contest: contest, score: 2)

      # cont2 beats cont1 -> should swap ranks (cont2 becomes 1)
      match = Match.create!(contest: contest, contester1: cont1, contester2: cont2, score1: 2, score2: 3,
                            match_time: Time.now.utc)
      cont1.reload
      cont2.reload
      # A win by cont2 should move it up one and push cont1 down one.
      expect([cont1.score, cont2.score]).to match_array([2, 1])

      # Now change the match so cont1 wins -> ranks should revert and then apply new result
      match.update!(score1: 3, score2: 2)

      cont1.reload
      cont2.reload
      # After changing the match so cont1 wins, the ranks should revert.
      expect([cont1.score, cont2.score]).to match_array([1, 2])
    end

    it 'evolves ranks across multiple ladder matches and updates' do
      contest = Contest.create!(name: 'LadderEvolution', start: Time.now.utc, end: 1.day.from_now.utc,
                                default_time: Time.now.utc, status: Contest::STATUS_OPEN, contest_type: Contest::TYPE_LADDER)

      team1 = Team.create!(name: 'Team Alpha', tag: 'TA')
      team2 = Team.create!(name: 'Team Bravo', tag: 'TB')
      team3 = Team.create!(name: 'Team Charlie', tag: 'TC')

      cont1 = Contester.create!(team: team1, contest: contest, score: 1)
      cont2 = Contester.create!(team: team2, contest: contest, score: 2)
      cont3 = Contester.create!(team: team3, contest: contest, score: 3)

      # Team Bravo beats Team Alpha -> swap ranks 1 and 2
      Match.create!(contest: contest, contester1: cont1, contester2: cont2, score1: 1, score2: 2,
                    match_time: Time.now.utc)
      cont1.reload
      cont2.reload
      cont3.reload
      expect([cont1.score, cont2.score, cont3.score]).to match_array([2, 1, 3])

      # Team Charlie beats Team Bravo (higher rank) -> Charlie moves to 1
      Match.create!(contest: contest, contester1: cont2, contester2: cont3, score1: 1, score2: 2,
                    match_time: Time.now.utc)
      cont1.reload
      cont2.reload
      cont3.reload
      expect([cont1.score, cont2.score, cont3.score]).to match_array([2, 3, 1])

      # Update the first match so Alpha wins instead -> should undo and reapply
      first_match = Match.where(contest: contest).ordered.last
      first_match.update!(score1: 3, score2: 1)

      cont1.reload
      cont2.reload
      cont3.reload
      expect([cont1.score, cont2.score, cont3.score]).to match_array([1, 3, 2])
    end

    it 'keeps ranks stable when lower-ranked team wins' do
      contest = Contest.create!(name: 'LadderStable', start: Time.now.utc, end: 1.day.from_now.utc,
                                default_time: Time.now.utc, status: Contest::STATUS_OPEN, contest_type: Contest::TYPE_LADDER)

      team1 = Team.create!(name: 'Team Delta', tag: 'TD')
      team2 = Team.create!(name: 'Team Echo', tag: 'TE')

      cont1 = Contester.create!(team: team1, contest: contest, score: 1)
      cont2 = Contester.create!(team: team2, contest: contest, score: 3)

      # Higher-ranked cont1 beats lower-ranked cont2 -> no rank change expected
      Match.create!(contest: contest, contester1: cont1, contester2: cont2, score1: 4, score2: 1,
                    match_time: Time.now.utc)

      cont1.reload
      cont2.reload
      expect([cont1.score, cont2.score]).to match_array([1, 3])
    end

    it 'moves lower-ranked team to just above on a draw' do
      contest = Contest.create!(name: 'LadderDraw', start: Time.now.utc, end: 1.day.from_now.utc,
                                default_time: Time.now.utc, status: Contest::STATUS_OPEN, contest_type: Contest::TYPE_LADDER)

      team1 = Team.create!(name: 'Team Foxtrot', tag: 'TF')
      team2 = Team.create!(name: 'Team Golf', tag: 'TG')

      cont1 = Contester.create!(team: team1, contest: contest, score: 2)
      cont2 = Contester.create!(team: team2, contest: contest, score: 4)

      # Lower-ranked cont2 draws higher-ranked cont1 -> cont2 moves just above cont1
      Match.create!(contest: contest, contester1: cont1, contester2: cont2, score1: 2, score2: 2,
                    match_time: Time.now.utc)

      cont1.reload
      cont2.reload
      expect([cont1.score, cont2.score]).to match_array([3, 1])
    end

    it 'reverts ladder ranks on draw update' do
      contest = Contest.create!(name: 'LadderDrawUpdate', start: Time.now.utc, end: 1.day.from_now.utc,
                                default_time: Time.now.utc, status: Contest::STATUS_OPEN, contest_type: Contest::TYPE_LADDER)

      team1 = Team.create!(name: 'Team Hotel', tag: 'TH')
      team2 = Team.create!(name: 'Team India', tag: 'TI')

      cont1 = Contester.create!(team: team1, contest: contest, score: 2)
      cont2 = Contester.create!(team: team2, contest: contest, score: 5)

      match = Match.create!(contest: contest, contester1: cont1, contester2: cont2, score1: 1, score2: 1,
                            match_time: Time.now.utc)

      cont1.reload
      cont2.reload
      expect([cont1.score, cont2.score]).to match_array([3, 1])

      # Change to cont1 win (higher-ranked) -> revert draw move
      match.update!(score1: 3, score2: 1)

      cont1.reload
      cont2.reload
      expect([cont1.score, cont2.score]).to match_array([2, 5])
    end
  end
end
