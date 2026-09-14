# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AlienStrategyQuery do
  def create_strategy_result(strategy:, metric:, value:, milestone:, batch_id: 1)
    create(:analysis_result, batch_id: batch_id, model: 'alien_strategy', steamid: strategy,
                             metric: metric, value: value, milestone: milestone)
  end

  describe '#canonical_roles' do
    it 'parses both legacy role labels and compact imported strategy paths' do
      query = described_class.new
      legacy = 'r1=gorge+hive,r2=skulk'
      compact = 'gorge+hive,skulk'

      expect(query.send(:canonical_roles, compact)).to eq(query.send(:canonical_roles, legacy))
    end

    it 'coalesces chamber variants, but not resource towers, when selected' do
      query = described_class.new(action_limit: nil, coalesce_chambers: true)

      expect(query.send(:canonical_roles, 'dc+dcs+mc+mcs+oc+ocs+sc+scs+rt+rts,skulk')).to include(
        %w[dc dc mc mc oc oc sc sc rt rts]
      )
    end
  end

  describe '#call' do
    before do
      10.times do |index|
        create_strategy_result(strategy: 'gorge,skulk,skulk,skulk,skulk,skulk',
                               metric: index < 6 ? 'alien_win' : 'marine_win',
                               value: index < 6 ? 900 : 0, milestone: index)
        create_strategy_result(strategy: 'fade,skulk,skulk,skulk,skulk,skulk', metric: 'alien_win',
                               value: 1800, milestone: index + 10)
      end
    end

    it 'ranks each role action by the rounds containing it' do
      results = described_class.new(action_limit: 1, min_rounds: 10, result_limit: nil,
                                    result_view: 'role_actions').call

      expect(results.first).to include(role: ['fade'], rounds: 10, wins: 10, losses: 0, win_ratio: 100.0)
      expect(results.find { |result| result[:role] == ['gorge'] }).to include(rounds: 10, wins: 6, losses: 4)
    end

    it 'filters role actions below the median win-time minimum' do
      results = described_class.new(action_limit: 1, min_rounds: 10, result_limit: nil,
                                    result_view: 'role_actions', min_median_win_time: 1200).call

      expect(results.map { |result| result[:role] }).to include(['fade'])
      expect(results.map { |result| result[:role] }).not_to include(['gorge'])
    end

    it 'filters displayed strategies without changing their analysis' do
      results = described_class.new(action_limit: 1, min_rounds: 10, result_limit: nil,
                                    result_view: 'role_actions', strategy_filter: 'gorge').call

      expect(results).to contain_exactly(include(role: ['gorge'], rounds: 10, wins: 6, losses: 4))
    end

    it 'requires all Contains tokens in one player action path' do
      10.times do |index|
        create_strategy_result(strategy: 'gorge+hive,skulk,skulk,skulk,skulk,skulk', metric: 'alien_win', value: 900,
                               milestone: index + 40)
        create_strategy_result(strategy: 'gorge,fade+hive,skulk,skulk,skulk,skulk', metric: 'alien_win', value: 900,
                               milestone: index + 50)
      end

      results = described_class.new(action_limit: 2, min_rounds: 10, result_limit: nil,
                                    strategy_filter: 'Gorge, Hive').call

      expect(results).to contain_exactly(include(roles: [
                                                   %w[gorge hive], ['skulk'], ['skulk'], ['skulk'], ['skulk'], ['skulk']
                                                 ], rounds: 10))
    end

    it 'only filters on actions visible at the selected action limit' do
      10.times do |index|
        create_strategy_result(strategy: 'gorge+hive,skulk,skulk,skulk,skulk,skulk', metric: 'alien_win', value: 900,
                               milestone: index + 60)
      end

      first_action = described_class.new(action_limit: 1, min_rounds: 10, result_limit: nil,
                                         strategy_filter: 'hive').call
      two_actions = described_class.new(action_limit: 2, min_rounds: 10, result_limit: nil,
                                        strategy_filter: 'hive').call

      expect(first_action).to be_empty
      expect(two_actions).to include(include(roles: [
                                               %w[gorge hive], ['skulk'], ['skulk'], ['skulk'], ['skulk'], ['skulk']
                                             ], rounds: 10))
    end

    it 'counts a repeated role action only once per round in role-action view' do
      10.times do |index|
        create_strategy_result(strategy: 'gorge,gorge,skulk,skulk,skulk,skulk', metric: 'alien_win', value: 900,
                               milestone: index + 70)
      end

      results = described_class.new(action_limit: 1, min_rounds: 10, result_limit: nil,
                                    result_view: 'role_actions').call

      expect(results).to include(include(role: ['gorge'], rounds: 20, wins: 16, losses: 4))
    end

    it 'merges offense chamber variants into the same analyzed group when selected' do
      5.times do |index|
        create_strategy_result(strategy: 'oc,skulk,skulk,skulk,skulk,skulk', metric: 'alien_win', value: 900,
                               milestone: index + 20)
        create_strategy_result(strategy: 'ocs,skulk,skulk,skulk,skulk,skulk', metric: 'alien_win', value: 900,
                               milestone: index + 30)
      end

      results = described_class.new(action_limit: 1, min_rounds: 10, result_limit: nil,
                                    result_view: 'role_actions', coalesce_chambers: true).call

      expect(results).to include(include(role: ['oc'], rounds: 10, wins: 10, losses: 0))
    end

    it 'matches coalesced chamber names in the Contains filter' do
      10.times do |index|
        create_strategy_result(strategy: 'ocs,skulk,skulk,skulk,skulk,skulk', metric: 'alien_win', value: 900,
                               milestone: index + 80)
      end

      results = described_class.new(action_limit: 1, min_rounds: 10, result_limit: nil,
                                    result_view: 'role_actions', coalesce_chambers: true,
                                    strategy_filter: 'oc').call

      expect(results).to include(include(role: ['oc'], rounds: 10, wins: 10))
    end

    it 'applies the result limit after filtering matching strategies' do
      10.times do |index|
        create_strategy_result(strategy: 'fade,skulk,skulk,skulk,skulk,skulk', metric: 'alien_win', value: 900,
                               milestone: index + 90)
        create_strategy_result(strategy: 'gorge,skulk,skulk,skulk,skulk,skulk', metric: 'marine_win', value: 0,
                               milestone: index + 100)
      end

      results = described_class.new(action_limit: 1, min_rounds: 10, result_limit: 1,
                                    strategy_filter: 'gorge').call

      expect(results).to contain_exactly(include(roles: [
                                                   ['gorge'], ['skulk'], ['skulk'], ['skulk'], ['skulk'], ['skulk']
                                                 ], rounds: 20, wins: 6, losses: 14))
    end

    it 'uses only the newest imported analysis batch' do
      10.times do |index|
        create_strategy_result(strategy: 'onos,skulk,skulk,skulk,skulk,skulk', metric: 'alien_win', value: 900,
                               milestone: index + 110, batch_id: 2)
      end

      results = described_class.new(action_limit: 1, min_rounds: 10, result_limit: nil).call

      expect(results).to contain_exactly(include(roles: [
                                                   ['onos'], ['skulk'], ['skulk'], ['skulk'], ['skulk'], ['skulk']
                                                 ], rounds: 10, wins: 10))
    end

    it 'includes the strongest qualifying groups from different action limits in best mode' do
      10.times do |index|
        create_strategy_result(strategy: 'gorge+hive,skulk,skulk,skulk,skulk,skulk',
                               metric: index < 8 ? 'alien_win' : 'marine_win',
                               value: index < 8 ? 900 : 0, milestone: index + 20)
        create_strategy_result(strategy: 'gorge+rt,skulk,skulk,skulk,skulk,skulk', metric: 'marine_win',
                               value: 0, milestone: index + 30)
      end

      results = described_class.new(action_limit: 'best', min_rounds: 10, result_limit: nil,
                                    result_view: 'strategies').call

      best_two_action_group = results.find do |result|
        result[:action_limit] == 2 && result[:roles].first == %w[gorge hive]
      end
      one_action_group = results.find do |result|
        result[:action_limit] == 1 && result[:roles].first == ['gorge']
      end

      expect(best_two_action_group).to include(rounds: 10, wins: 8, losses: 2, win_ratio: 80.0)
      expect(one_action_group).to include(rounds: 30, wins: 14, losses: 16,
                                          win_ratio: (14 * 100.0 / 30))
    end
  end

  describe 'defaults' do
    it 'starts with best action limits, twenty-five rounds, and six-player strategies' do
      expect(described_class::DEFAULT_ACTION_LIMIT).to eq('best')
      expect(described_class::DEFAULT_MIN_ROUNDS).to eq(25)
      expect(described_class::DEFAULT_RESULT_LIMIT).to eq(25)
      expect(described_class::DEFAULT_RESULT_VIEW).to eq('strategies')
    end
  end

  describe '#filter_options' do
    it 'returns the action tokens accepted by the contains filter' do
      create_strategy_result(strategy: 'gorge+rt,skulk', metric: 'alien_win', value: 900, milestone: 99)

      expect(described_class.new.filter_options).to eq(%w[gorge rt skulk])
    end

    it 'uses the selected chamber coalescing rule' do
      create_strategy_result(strategy: 'ocs,skulk', metric: 'alien_win', value: 900, milestone: 100)

      expect(described_class.new(coalesce_chambers: true).filter_options).to include('oc')
      expect(described_class.new(coalesce_chambers: true).filter_options).not_to include('ocs')
    end
  end
end
