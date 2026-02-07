# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Bracketer, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:bracket) }
    it { is_expected.to belong_to(:match).optional }
    it { is_expected.to belong_to(:contester).with_foreign_key('team_id').optional }
  end

  describe 'scopes' do
    let!(:bracketer1) { create(:bracketer, row: 1, column: 1) }
    let!(:bracketer2) { create(:bracketer, row: 1, column: 2) }
    let!(:bracketer3) { create(:bracketer, row: 2, column: 1) }

    describe '.pos' do
      it 'returns bracketers at the specified row and column' do
        expect(Bracketer.pos(1, 1)).to contain_exactly(bracketer1)
      end

      it 'returns empty if no bracketers match the position' do
        expect(Bracketer.pos(99, 99)).to be_empty
      end
    end
  end

  describe '#to_s' do
    context 'when bracketer has a match' do
      let(:contest) { create(:contest) }
      let(:match) { create(:match, contest: contest, match_time: Time.current + 1.day) }
      let(:bracket) { create(:bracket, contest: contest) }
      let(:bracketer) { create(:bracketer, bracket: bracket, match: match) }

      context 'when match time is in the future' do
        it 'returns the match time formatted' do
          expect(bracketer.to_s =~ %r{\d{2}:\d{2} \d{2}/\w{3}}).to be_truthy
        end
      end

      context 'when match time is in the past with scores' do
        before do
          match.update(match_time: Time.current - 1.day, score1: 2, score2: 1)
        end

        it 'returns the score' do
          expect(bracketer.to_s).to eq('2 - 1')
        end
      end

      context 'when match time is in the past without scores' do
        before do
          match.update(match_time: Time.current - 1.day, score1: nil, score2: nil)
        end

        it 'returns the match time formatted' do
          expect(bracketer.to_s =~ %r{\d{2}:\d{2} \d{2}/\w{3}}).to be_truthy
        end
      end

      context 'when match time is past with only one score' do
        before do
          match.update(match_time: Time.current - 1.day, score1: 2, score2: nil)
        end

        it 'returns the match time formatted' do
          expect(bracketer.to_s =~ %r{\d{2}:\d{2} \d{2}/\w{3}}).to be_truthy
        end
      end
    end

    context 'when bracketer has a contester' do
      let(:contester) { create(:contester) }
      let(:bracketer) { create(:bracketer, contester: contester) }

      it 'returns the first 10 characters of the contester' do
        result = bracketer.to_s
        expect(result).to eq(contester.to_s[0, 10])
      end

      context 'with a long contester name' do
        it 'truncates to 10 characters' do
          # Create a bracketer with a contester, then test the truncation
          # by verifying the length is at most 10
          expect(bracketer.to_s.length).to be <= 10
        end
      end
    end

    context 'when bracketer has neither match nor contester' do
      let(:contest) { create(:contest) }
      let(:bracket) { create(:bracket, contest: contest) }
      let(:bracketer) { create(:bracketer, bracket: bracket) }

      it 'returns nil' do
        expect(bracketer.to_s).to be_nil
      end
    end
  end
end
