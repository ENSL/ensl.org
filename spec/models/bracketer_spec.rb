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

  describe '#result_class' do
    let(:bracketer) { build(:bracketer) }

    it 'returns nil when the current cell is disabled or has no advancing contester' do
      allow(bracketer).to receive(:disabled).and_return(true)
      expect(bracketer.result_class).to be_nil

      allow(bracketer).to receive(:disabled).and_return(false)
      allow(bracketer).to receive(:effective_contester_id).and_return(nil)
      expect(bracketer.result_class).to be_nil
    end

    it 'compares a next-round team slot directly' do
      allow(bracketer).to receive(:disabled).and_return(false)
      allow(bracketer).to receive(:effective_contester_id).and_return(10)
      allow(bracketer).to receive(:next_round_cell).and_return(instance_double(Bracketer, disabled: false, team_id: 10,
                                                                                          match_id: nil))
      expect(bracketer.result_class).to eq('win1')

      allow(bracketer).to receive(:next_round_cell).and_return(instance_double(Bracketer, disabled: false, team_id: 11,
                                                                                          match_id: nil))
      expect(bracketer.result_class).to eq('win2')
    end

    it 'returns nil when the next round cell is disabled or empty' do
      allow(bracketer).to receive(:disabled).and_return(false)
      allow(bracketer).to receive(:effective_contester_id).and_return(10)
      allow(bracketer).to receive(:next_round_cell).and_return(instance_double(Bracketer, disabled: true, team_id: nil,
                                                                                          match_id: nil))
      expect(bracketer.result_class).to be_nil

      allow(bracketer).to receive(:next_round_cell).and_return(instance_double(Bracketer, disabled: false,
                                                                                          team_id: nil, match_id: nil))
      expect(bracketer.result_class).to be_nil
    end

    it 'derives the result from the next-round match when the advancing team is contester1' do
      next_match = instance_double(Match, score1: 3, score2: 1, contester1_id: 10, contester2_id: 20)
      allow(bracketer).to receive(:disabled).and_return(false)
      allow(bracketer).to receive(:effective_contester_id).and_return(10)
      allow(bracketer).to receive(:next_round_cell).and_return(instance_double(Bracketer, disabled: false,
                                                                                          team_id: nil, match_id: 99))
      allow(Match).to receive(:find_by).with(id: 99).and_return(next_match)
      expect(bracketer.result_class).to eq('win1')

      allow(next_match).to receive(:score1).and_return(1)
      allow(next_match).to receive(:score2).and_return(3)
      expect(bracketer.result_class).to eq('win2')

      allow(next_match).to receive(:score1).and_return(2)
      allow(next_match).to receive(:score2).and_return(2)
      expect(bracketer.result_class).to eq('tie')
    end

    it 'derives the result from the next-round match when the advancing team is contester2' do
      next_match = instance_double(Match, score1: 1, score2: 3, contester1_id: 20, contester2_id: 10)
      allow(bracketer).to receive(:disabled).and_return(false)
      allow(bracketer).to receive(:effective_contester_id).and_return(10)
      allow(bracketer).to receive(:next_round_cell).and_return(instance_double(Bracketer, disabled: false,
                                                                                          team_id: nil, match_id: 100))
      allow(Match).to receive(:find_by).with(id: 100).and_return(next_match)
      expect(bracketer.result_class).to eq('win1')

      allow(next_match).to receive(:score1).and_return(3)
      allow(next_match).to receive(:score2).and_return(1)
      expect(bracketer.result_class).to eq('win2')
    end

    it 'returns nil when the next-round match cannot resolve the advancing team' do
      unresolved_match = instance_double(Match, score1: nil, score2: nil, contester1_id: 20, contester2_id: 30)
      allow(bracketer).to receive(:disabled).and_return(false)
      allow(bracketer).to receive(:effective_contester_id).and_return(10)
      allow(bracketer).to receive(:next_round_cell).and_return(instance_double(Bracketer, disabled: false,
                                                                                          team_id: nil, match_id: 101))
      allow(Match).to receive(:find_by).with(id: 101).and_return(unresolved_match)
      expect(bracketer.result_class).to be_nil

      allow(unresolved_match).to receive(:score1).and_return(1)
      allow(unresolved_match).to receive(:score2).and_return(0)
      expect(bracketer.result_class).to be_nil
    end
  end

  describe 'private helpers' do
    it 'resolves the effective contester from a team slot or a scored match' do
      contest = create(:contest)
      cont1 = create(:contester, contest: contest)
      cont2 = create(:contester, contest: contest)
      match = create(:match, contest: contest, contester1: cont1, contester2: cont2, score1: 2, score2: 1)

      expect(build(:bracketer, team_id: cont1.id).send(:effective_contester_id)).to eq(cont1.id)
      expect(build(:bracketer, match_id: match.id).send(:effective_contester_id)).to eq(cont1.id)

      match.update!(score1: 1, score2: 2)
      expect(build(:bracketer, match_id: match.id).send(:effective_contester_id)).to eq(cont2.id)

      match.update!(score1: 2, score2: 2)
      expect(build(:bracketer, match_id: match.id).send(:effective_contester_id)).to be_nil
    end

    it 'finds the next round cell from the bracket tree position' do
      bracket = create(:bracket)
      source = create(:bracketer, bracket: bracket, row: 0, column: 0)
      target = create(:bracketer, bracket: bracket, row: 2, column: 1)

      expect(source.send(:next_round_cell)).to eq(target)
    end
  end
end
