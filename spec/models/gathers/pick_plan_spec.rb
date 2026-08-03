# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Gathers::PickPlan do
  subject(:plan) { described_class.new(strategy: strategy, team_size: 6) }

  let(:strategy) { described_class::DEFAULT_STRATEGY }

  describe '#transition' do
    it 'changes teams at the default strategy boundaries' do
      expect(plan.transition(current_turn: 1, team1_count: 2, team2_count: 1)).to eq(:team_two)
      expect(plan.transition(current_turn: 2, team1_count: 2, team2_count: 2)).to be_nil
      expect(plan.transition(current_turn: 2, team1_count: 2, team2_count: 3)).to eq(:team_one)
    end

    it 'fills the final team slot and finishes full teams' do
      expect(plan.transition(current_turn: 1, team1_count: 6, team2_count: 5)).to eq(:fill_team_two)
      expect(plan.transition(current_turn: 2, team1_count: 6, team2_count: 6)).to eq(:finish)
    end

    it 'repeats shorter strategies until all slots are assigned' do
      alternate_plan = described_class.new(strategy: '1-1-1-1', team_size: 6)

      expect(alternate_plan.transition(current_turn: 1, team1_count: 2, team2_count: 1)).to eq(:team_two)
      expect(alternate_plan.transition(current_turn: 2, team1_count: 2, team2_count: 2)).to eq(:team_one)
      expect(alternate_plan.transition(current_turn: 1, team1_count: 3, team2_count: 2)).to eq(:team_two)
    end

    it 'maps named future strategies to the default schedule explicitly' do
      named_plan = described_class.new(strategy: 'random', team_size: 6)

      expect(named_plan.transition(current_turn: 2, team1_count: 2, team2_count: 2)).to be_nil
      expect(named_plan.transition(current_turn: 2, team1_count: 2, team2_count: 3)).to eq(:team_one)
    end

    it 'preserves a manual turn override until that team completes a segment' do
      expect(plan.transition(current_turn: 2, team1_count: 1, team2_count: 1)).to be_nil
    end
  end

  describe '#slot_available?' do
    it 'allows only the team assigned to the next pick' do
      expect(plan.slot_available?(turn: 1, team1_count: 1, team2_count: 1)).to be true
      expect(plan.slot_available?(turn: 2, team1_count: 1, team2_count: 1)).to be false
    end
  end
end
