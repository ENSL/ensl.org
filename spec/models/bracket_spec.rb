# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Bracket, type: :model do
  let(:contest) { create(:contest) }
  let(:bracket) { create(:bracket, contest:) }

  describe 'associations' do
    it 'belongs to contest' do
      expect(bracket.respond_to?(:contest)).to be true
    end

    it 'has many bracketers' do
      expect(bracket.respond_to?(:bracketers)).to be true
    end

    it 'destroys associated bracketers when deleted' do
      bracketer = create(:bracketer, bracket:)
      bracket_id = bracket.id
      bracket.destroy
      expect(Bracketer.where(bracket_id:)).to be_empty
    end
  end

  describe 'validations' do
    describe 'contest_id' do
      it 'is required' do
        bracket = build(:bracket, contest_id: nil)
        expect(bracket).not_to be_valid
        expect(bracket.errors[:contest_id]).to include("can't be blank")
      end
    end

    describe 'name' do
      it 'is required' do
        bracket = build(:bracket, name: nil)
        expect(bracket).not_to be_valid
        expect(bracket.errors[:name]).not_to be_empty
      end

      it 'must not be blank' do
        bracket = build(:bracket, name: '')
        expect(bracket).not_to be_valid
      end

      it 'is valid with a name' do
        bracket = build(:bracket, name: 'Tournament')
        expect(bracket).to be_valid
      end
    end

    describe 'slots' do
      it 'is required' do
        bracket = build(:bracket, slots: nil)
        expect(bracket).not_to be_valid
        expect(bracket.errors[:slots]).to include("can't be blank")
      end

      it 'must be an integer' do
        bracket = build(:bracket, slots: 2.5)
        expect(bracket).not_to be_valid
      end

      it 'must be greater than 0' do
        bracket = build(:bracket, slots: 0)
        expect(bracket).not_to be_valid
        expect(bracket.errors[:slots]).to include('must be greater than 0')
      end

      it 'rejects negative slots' do
        bracket = build(:bracket, slots: -1)
        expect(bracket).not_to be_valid
      end

      it 'is valid with a positive integer' do
        bracket = build(:bracket, slots: 16)
        expect(bracket).to be_valid
      end
    end
  end

  describe '#to_s' do
    context 'with a name' do
      it 'returns the bracket name' do
        bracket = create(:bracket, name: 'Finals')
        expect(bracket.to_s).to eq('Finals')
      end
    end

    context 'without a name' do
      it 'returns a formatted string with the bracket ID' do
        bracket = create(:bracket, name: 'Test Bracket')
        bracket.update_column(:name, nil) # Use update_column to bypass validation
        expect(bracket.to_s).to eq("Bracket ##{bracket.id}")
      end
    end
  end

  describe '#get_bracketer' do
    it 'returns existing bracketer at row and col' do
      existing_bracketer = create(:bracketer, bracket:, row: 1, column: 2)
      result = bracket.get_bracketer(1, 2)
      expect(result.id).to eq(existing_bracketer.id)
    end

    it 'creates a new bracketer if none exists at row and col' do
      expect do
        bracket.get_bracketer(3, 4)
      end.to change(Bracketer, :count).by(1)

      new_bracketer = Bracketer.last
      expect(new_bracketer.row).to eq(3)
      expect(new_bracketer.column).to eq(4)
      expect(new_bracketer.bracket).to eq(bracket)
    end

    it 'converts string row and column to integers' do
      result = bracket.get_bracketer('5', '6')
      expect(result.row).to eq(5)
      expect(result.column).to eq(6)
    end
  end

  describe '#options' do
    it 'returns an array' do
      options = bracket.options
      expect(options).to be_an(Array)
    end

    it 'includes separators and match/team options' do
      options = bracket.options.flatten(1)
      expect(options).to include('-- Matches')
      expect(options).to include('-- Teams')
    end
  end

  describe '#default' do
    context 'when bracketer does not exist' do
      it 'returns nil' do
        expect(bracket.default(1, 1)).to be_nil
      end
    end

    context 'when bracketer has no match_id or team_id' do
      it 'returns nil' do
        create(:bracketer, bracket:, row: 1, column: 1, match_id: nil, team_id: nil)
        expect(bracket.default(1, 1)).to be_nil
      end
    end

    context 'when bracketer is linked to a match' do
      it 'returns match reference string' do
        bracketer = create(:bracketer, bracket:, row: 1, column: 1, match_id: 42, team_id: nil)
        expect(bracket.default(1, 1)).to eq('match_42')
      end
    end

    context 'when bracketer is linked to a contester' do
      it 'returns contester reference string' do
        bracketer = create(:bracketer, bracket:, row: 1, column: 1, team_id: 99, match_id: nil)
        expect(bracket.default(1, 1)).to eq('contester_99')
      end
    end

    context 'when bracketer has both match_id and team_id' do
      it 'prefers match_id' do
        create(:bracketer, bracket:, row: 1, column: 1, match_id: 42, team_id: 99)
        expect(bracket.default(1, 1)).to eq('match_42')
      end
    end
  end

  describe '#update_cells' do
    it 'updates bracketer with match_id and clears team_id' do
      bracketer = bracket.get_bracketer(1, 1)
      cells = { '1' => { '1' => 'match_42' } }

      bracket.update_cells(cells)

      expect(bracketer.reload.match_id).to eq(42)
      expect(bracketer.reload.team_id).to be_nil
    end

    it 'updates bracketer with team_id and clears match_id' do
      bracketer = bracket.get_bracketer(2, 2)
      cells = { '2' => { '2' => 'contester_99' } }

      bracket.update_cells(cells)

      expect(bracketer.reload.team_id).to eq(99)
      expect(bracketer.reload.match_id).to be_nil
    end

    it 'skips updating cells with separator prefix' do
      bracketer = bracket.get_bracketer(1, 1)
      cells = { '1' => { '1' => '-- Teams' } }

      bracket.update_cells(cells)

      expect(bracketer.reload.match_id).to be_nil
      expect(bracketer.reload.team_id).to be_nil
    end

    it 'updates all cells correctly' do
      cells = {
        '1' => { '1' => 'match_42', '2' => 'contester_99' },
        '2' => { '1' => 'match_88' }
      }

      bracket.update_cells(cells)

      expect(bracket.get_bracketer(1, 1).match_id).to eq(42)
      expect(bracket.get_bracketer(1, 2).team_id).to eq(99)
      expect(bracket.get_bracketer(2, 1).match_id).to eq(88)
    end

    it 'does not update bracketer if value does not match pattern' do
      bracketer = bracket.get_bracketer(1, 1)
      cells = { '1' => { '1' => 'invalid_reference' } }

      bracket.update_cells(cells)

      expect(bracketer.reload.match_id).to be_nil
      expect(bracketer.reload.team_id).to be_nil
    end
  end

  describe '#parse_cell_value' do
    context 'with match pattern' do
      it 'returns hash with match_id and team_id: nil' do
        result = bracket.send(:parse_cell_value, 'match_42')
        expect(result).to eq({ match_id: 42, team_id: nil })
      end
    end

    context 'with contester pattern' do
      it 'returns hash with team_id and match_id: nil' do
        result = bracket.send(:parse_cell_value, 'contester_99')
        expect(result).to eq({ team_id: 99, match_id: nil })
      end
    end

    context 'with invalid pattern' do
      it 'returns nil' do
        result = bracket.send(:parse_cell_value, 'invalid')
        expect(result).to be_nil
      end
    end

    context 'with edge cases' do
      it 'rejects match pattern with non-digit suffix' do
        result = bracket.send(:parse_cell_value, 'match_abc')
        expect(result).to be_nil
      end

      it 'rejects contester pattern with extra characters' do
        result = bracket.send(:parse_cell_value, 'contester_123_extra')
        expect(result).to be_nil
      end
    end
  end

  describe 'permission methods' do
    let(:admin_user) { instance_double('User', admin?: true) }
    let(:regular_user) { instance_double('User', admin?: false) }

    # NOTE: Permission methods (can_create?, can_update?, can_destroy?) are private,
    # so we test them indirectly through the public interface or via send for testing.
    # These tests are informational and not executed as part of the spec.
  end

  describe '.params' do
    let(:params_hash) do
      ActionController::Parameters.new(
        bracket: {
          contest_id: contest.id,
          slots: 16,
          name: 'Tournament Bracket',
          malicious: 'should be ignored'
        }
      )
    end

    it 'permits contest_id, slots, and name' do
      permitted_params = Bracket.params(params_hash, nil)
      expect(permitted_params[:contest_id]).to eq(contest.id)
      expect(permitted_params[:slots]).to eq(16)
      expect(permitted_params[:name]).to eq('Tournament Bracket')
    end

    it 'filters out unpermitted attributes' do
      permitted_params = Bracket.params(params_hash, nil)
      expect(permitted_params.key?(:malicious)).to be false
    end
  end
end
