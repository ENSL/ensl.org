# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Match, type: :model do
  # Ladder ranks live in Contester#score: 1 is the top rank and the values must stay
  # contiguous (1..N) across every active contester of the ladder.
  let(:contest) { create(:contest, contest_type: Contest::TYPE_LADDER) }

  def build_ladder(size)
    Array.new(size) { |index| create(:contester, contest: contest, team: create(:team), score: index + 1) }
  end

  def play(home, away, score1, score2, time = 1.hour.ago)
    Match.create!(contest: contest, contester1: home, contester2: away,
                  score1: score1, score2: score2, match_time: time)
  end

  def ranks(*contesters)
    contesters.map { |contester| contester.reload.score }
  end

  def rank_order
    contest.contesters.active.ranked.map { |contester| contester.team.name }
  end

  describe 'applying a ladder result' do
    it 'moves the winner into the rank of the better-ranked opponent' do
      a, b, c, d = build_ladder(4)

      play(c, a, 3, 1)

      expect(ranks(a, b, c, d)).to eq([2, 3, 1, 4])
    end

    it 'moves the winner up when it is the away team' do
      a, b, c, d = build_ladder(4)

      play(a, d, 1, 3)

      expect(ranks(a, b, c, d)).to eq([2, 3, 4, 1])
    end

    it 'leaves ranks untouched when the better-ranked team wins' do
      a, b, c, d = build_ladder(4)

      play(a, d, 4, 1)

      expect(ranks(a, b, c, d)).to eq([1, 2, 3, 4])
    end

    it 'leaves ranks untouched when the better-ranked away team wins' do
      a, b, c, d = build_ladder(4)

      play(d, a, 1, 4)

      expect(ranks(a, b, c, d)).to eq([1, 2, 3, 4])
    end

    it 'moves a drawing challenger to the rank directly below its opponent' do
      a, b, c, d = build_ladder(4)

      play(b, d, 2, 2)

      expect(ranks(a, b, c, d)).to eq([1, 2, 4, 3])
    end

    it 'moves a drawing home challenger to the rank directly below its opponent' do
      a, b, c, d = build_ladder(4)

      play(d, b, 2, 2)

      expect(ranks(a, b, c, d)).to eq([1, 2, 4, 3])
    end

    it 'never promotes a drawing challenger past the team it drew with' do
      a, b, c, d = build_ladder(4)

      play(a, c, 1, 1)

      expect(ranks(a, b, c, d)).to eq([1, 3, 2, 4])
      expect(a.reload.score).to be < c.reload.score
    end

    it 'never produces a rank below 1 when drawing with the top team' do
      a, b = build_ladder(2)

      play(a, b, 1, 1)

      expect(ranks(a, b)).to eq([1, 2])
    end

    it 'leaves adjacent ranks untouched on a draw' do
      a, b, c, d = build_ladder(4)

      play(b, c, 2, 2)

      expect(ranks(a, b, c, d)).to eq([1, 2, 3, 4])
    end

    it 'records the rank gap it acted on' do
      a, _b, c, _d = build_ladder(4)

      match = play(c, a, 3, 1)

      expect(match.reload.diff).to eq(-2)
    end

    it 'updates win, loss and draw records' do
      a, b, = build_ladder(3)

      play(a, b, 3, 1)

      expect([a.reload.win, a.loss, a.draw]).to eq([1, 0, 0])
      expect([b.reload.win, b.loss, b.draw]).to eq([0, 1, 0])
    end

    it 'keeps ranks contiguous after a series of results' do
      a, b, c, d = build_ladder(4)

      play(d, a, 3, 1, 4.hours.ago)
      play(b, c, 2, 2, 3.hours.ago)
      play(c, d, 1, 3, 2.hours.ago)
      play(a, b, 4, 2, 1.hour.ago)

      expect(ranks(a, b, c, d).sort).to eq([1, 2, 3, 4])
    end
  end

  describe 'rescoring a ladder match' do
    it 'reverts a win and applies the new result' do
      a, b, c, d = build_ladder(4)
      match = play(c, a, 3, 1)
      expect(ranks(a, b, c, d)).to eq([2, 3, 1, 4])

      match.update!(score1: 1, score2: 3)

      expect(ranks(a, b, c, d)).to eq([1, 2, 3, 4])
      expect([a.reload.win, a.loss]).to eq([1, 0])
      expect([c.reload.win, c.loss]).to eq([0, 1])
    end

    it 'reverts a win into a draw' do
      a, b, c, d = build_ladder(4)
      match = play(c, a, 3, 1)

      match.update!(score1: 2, score2: 2)

      expect(ranks(a, b, c, d)).to eq([1, 3, 2, 4])
      expect(a.reload.draw).to eq(1)
      expect(c.reload.draw).to eq(1)
    end

    it 'reverts a draw into a win' do
      a, b, c, d = build_ladder(4)
      match = play(b, d, 2, 2)
      expect(ranks(a, b, c, d)).to eq([1, 2, 4, 3])

      match.update!(score1: 4, score2: 1)

      expect(ranks(a, b, c, d)).to eq([1, 2, 3, 4])
      expect(b.reload.draw).to eq(0)
      expect(d.reload.draw).to eq(0)
    end

    it 'reverts a draw into the opposite win' do
      a, b, c, d = build_ladder(4)
      match = play(b, d, 2, 2)

      match.update!(score1: 1, score2: 4)

      expect(ranks(a, b, c, d)).to eq([1, 3, 4, 2])
    end

    it 'is a no-op when a result that changed nothing is rescored' do
      a, b, c, d = build_ladder(4)
      match = play(a, d, 4, 1)

      match.update!(score1: 3, score2: 2)

      expect(ranks(a, b, c, d)).to eq([1, 2, 3, 4])
    end

    it 'recomputes the stored rank gap instead of reusing a stale one' do
      a, b, c, d = build_ladder(4)
      match = play(c, a, 3, 1, 2.hours.ago)
      play(d, b, 3, 1, 1.hour.ago)

      match.update!(score1: 1, score2: 3)

      expect(match.reload.diff).to eq(a.reload.score - c.reload.score)
      expect(ranks(a, b, c, d).sort).to eq([1, 2, 3, 4])
    end

    it 'keeps ranks contiguous when a match in the middle of a series is rescored' do
      a, b, c, d = build_ladder(4)
      play(d, a, 3, 1, 3.hours.ago)
      match = play(b, c, 1, 3, 2.hours.ago)
      play(a, d, 3, 1, 1.hour.ago)

      match.update!(score1: 3, score2: 1)

      expect(ranks(a, b, c, d).sort).to eq([1, 2, 3, 4])
    end
  end

  describe 'destroying a ladder match' do
    it 'reverts the rank move it caused' do
      a, b, c, d = build_ladder(4)
      match = play(c, a, 3, 1)

      match.destroy

      expect(ranks(a, b, c, d)).to eq([1, 2, 3, 4])
    end

    it 'reverts a draw move' do
      a, b, c, d = build_ladder(4)
      match = play(b, d, 2, 2)

      match.destroy

      expect(ranks(a, b, c, d)).to eq([1, 2, 3, 4])
    end

    it 'reverts win and loss records' do
      a, b, = build_ladder(3)
      match = play(a, b, 3, 1)

      match.destroy

      expect([a.reload.win, a.loss]).to eq([0, 0])
      expect([b.reload.win, b.loss]).to eq([0, 0])
    end

    it 'keeps the effect of the remaining matches' do
      a, b, c, d = build_ladder(4)
      match = play(c, a, 3, 1, 2.hours.ago)
      play(d, b, 3, 1, 1.hour.ago)

      match.destroy

      expect(ranks(a, b, c, d).sort).to eq([1, 2, 3, 4])
      expect(d.reload.win).to eq(1)
      expect(d.score).to be < b.reload.score
    end
  end
end
