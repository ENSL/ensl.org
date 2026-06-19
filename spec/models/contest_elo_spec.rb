# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Contest, type: :model do
  describe '#elo_score' do
    let(:contest) { Contest.new(modulus_base: 30, modulus_even: 1.0, modulus_3to1: 1.5, modulus_4to0: 2.0, weight: 30) }

    it 'returns 0 for a draw when diff is 0' do
      expect(contest.elo_score(1, 1, 0)).to eq 0
    end

    it 'awards positive points to a winner and negative to a loser (diff 0)' do
      expect(contest.elo_score(2, 1, 0)).to eq 15
      expect(contest.elo_score(1, 2, 0)).to eq(-15)
    end

    it 'gives at least as large magnitude change for very large diff (non-decreasing)' do
      small = contest.elo_score(2, 1, 0)
      big = contest.elo_score(2, 1, 1000)
      expect(big.abs).to be >= small.abs
    end

    it 'treats a zero weight as fallback to default WEIGHT' do
      default = contest.elo_score(2, 1, 0)
      zero_weight = contest.elo_score(2, 1, 0, nil, 0)
      expect(zero_weight).to eq default
    end
  end
end
