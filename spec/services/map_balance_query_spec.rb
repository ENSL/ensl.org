# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MapBalanceQuery do
  def map_balance_row(map_name, values)
    create_analysis_row(batch_id: AnalysisResult::CURRENT_SNAPSHOT_BATCH_ID, model: 'map_balance',
                        values: { 'map_name' => map_name }.merge(values))
  end

  describe '.call' do
    it 'returns maps with positive total games sorted by marine win rate descending' do
      map_balance_row('ns_tram', 'total_games' => 12, 'marine_wins' => 7, 'alien_wins' => 5,
                                 'marine_win_percentage' => 58.3, 'alien_win_percentage' => 41.7)
      map_balance_row('ns_veil', 'total_games' => 20, 'marine_wins' => 10, 'alien_wins' => 10)
      map_balance_row('ns_unused', 'total_games' => 0)

      rows = described_class.call

      expect(rows.map { |r| r[:map_name] }).to eq(%w[ns_tram ns_veil])
      expect(rows.first[:marine_win_percentage]).to eq(58.3)
      expect(rows.first[:alien_win_percentage]).to eq(41.7)
    end

    it 'ignores incomplete rows without a map name' do
      create_analysis_row(batch_id: AnalysisResult::CURRENT_SNAPSHOT_BATCH_ID, model: 'map_balance',
                          values: { 'total_games' => 50 })

      expect(described_class.call).to eq([])
    end
  end
end
