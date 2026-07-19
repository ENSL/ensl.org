# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MapBalanceQuery do
  describe '.call' do
    it 'returns maps with positive total games sorted by total_games descending' do
      create(:analysis_result, batch_id: AnalysisResult::CURRENT_SNAPSHOT_BATCH_ID,
                               steamid: 'ns_tram', model: 'map_balance', metric: 'total_games', value: 12)
      create(:analysis_result, batch_id: AnalysisResult::CURRENT_SNAPSHOT_BATCH_ID,
                               steamid: 'ns_tram', model: 'map_balance', metric: 'marine_wins', value: 7)
      create(:analysis_result, batch_id: AnalysisResult::CURRENT_SNAPSHOT_BATCH_ID,
                               steamid: 'ns_tram', model: 'map_balance', metric: 'alien_wins', value: 5)
      create(:analysis_result, batch_id: AnalysisResult::CURRENT_SNAPSHOT_BATCH_ID,
                               steamid: 'ns_tram', model: 'map_balance', metric: 'marine_win_percentage', value: 58.3)
      create(:analysis_result, batch_id: AnalysisResult::CURRENT_SNAPSHOT_BATCH_ID,
                               steamid: 'ns_tram', model: 'map_balance', metric: 'alien_win_percentage', value: 41.7)

      create(:analysis_result, batch_id: AnalysisResult::CURRENT_SNAPSHOT_BATCH_ID,
                               steamid: 'ns_veil', model: 'map_balance', metric: 'total_games', value: 20)
      create(:analysis_result, batch_id: AnalysisResult::CURRENT_SNAPSHOT_BATCH_ID,
                               steamid: 'ns_veil', model: 'map_balance', metric: 'marine_wins', value: 10)
      create(:analysis_result, batch_id: AnalysisResult::CURRENT_SNAPSHOT_BATCH_ID,
                               steamid: 'ns_veil', model: 'map_balance', metric: 'alien_wins', value: 10)

      create(:analysis_result, batch_id: AnalysisResult::CURRENT_SNAPSHOT_BATCH_ID,
                               steamid: 'ns_unused', model: 'map_balance', metric: 'total_games', value: 0)

      rows = described_class.call

      expect(rows.map { |r| r[:map_name] }).to eq(%w[ns_veil ns_tram])
      expect(rows.first[:total_games]).to eq(20)
      expect(rows.last[:marine_win_percentage]).to eq(58.3)
      expect(rows.last[:alien_win_percentage]).to eq(41.7)
    end

    it 'ignores rows with nil or sentinel steamid values' do
      create(:analysis_result, batch_id: AnalysisResult::CURRENT_SNAPSHOT_BATCH_ID,
                               steamid: AnalysisResult::NO_STEAMID, model: 'map_balance',
                               metric: 'total_games', value: 50)
      create(:analysis_result, batch_id: AnalysisResult::CURRENT_SNAPSHOT_BATCH_ID,
                               steamid: nil, model: 'map_balance', metric: 'total_games', value: 20)

      expect(described_class.call).to eq([])
    end
  end
end
