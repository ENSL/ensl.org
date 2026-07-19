# frozen_string_literal: true

require 'rails_helper'

describe PlayerRankingQuery do
  describe '#call' do
    it 'returns an empty array when there are no historical batches' do
      expect(described_class.call).to eq([])
    end

    it 'pivots the latest batch into one row per known player' do
      user = create(:user, steamid: '0:1:11111')

      # Older batch -- should be ignored in favour of the latest one.
      create(:analysis_result, batch_id: 1, steamid: user.steamid, model: 'os', metric: 'skill', value: 10.0)

      create(:analysis_result, batch_id: 2, steamid: user.steamid, model: 'os', metric: 'skill', value: 25.5)
      create(:analysis_result, batch_id: 2, steamid: user.steamid, model: 'dl', metric: 'skill', value: 30.0)
      create(:analysis_result, batch_id: 2, steamid: user.steamid, model: 'player_stats', metric: 'wins', value: 12)
      create(:analysis_result, batch_id: 2, steamid: user.steamid, model: 'player_stats', metric: 'losses', value: 4)
      create(:analysis_result, batch_id: 2, steamid: user.steamid, model: 'player_stats', metric: 'win_ratio',
                               value: 0.75)

      # No matching User -- should be skipped.
      create(:analysis_result, batch_id: 2, steamid: '0:1:99999', model: 'os', metric: 'skill', value: 5.0)

      rankings = described_class.call

      expect(rankings.size).to eq(1)
      ranking = rankings.first
      expect(ranking[:user]).to eq(user)
      expect(ranking[:skill_os]).to eq(25.5)
      expect(ranking[:skill_dl]).to eq(30.0)
      expect(ranking[:wins]).to eq(12)
      expect(ranking[:losses]).to eq(4)
      expect(ranking[:win_ratio]).to eq(0.75)
      expect(ranking[:skill_mlt]).to be_nil
    end

    it 'matches analysis steamids in STEAM_ format to normalized users and handles mixed-case models' do
      user = create(:user, steamid: '0:1:33333')

      create(:analysis_result, batch_id: 3, steamid: 'STEAM_0:1:33333', model: 'os', metric: 'skill', value: 22.0)
      create(:analysis_result, batch_id: 3, steamid: 'STEAM_0:1:33333', model: 'DL', metric: 'skill', value: 28.5)
      create(:analysis_result, batch_id: 3, steamid: 'STEAM_0:1:33333', model: 'player_stats', metric: 'wins', value: 9)

      ranking = described_class.call.find { |row| row[:user] == user }

      expect(ranking).not_to be_nil
      expect(ranking[:skill_os]).to eq(22.0)
      expect(ranking[:skill_dl]).to eq(28.5)
      expect(ranking[:wins]).to eq(9)
    end

    it 'excludes current-state snapshot rows (batch_id 0)' do
      user = create(:user, steamid: '0:1:22222')
      create(:analysis_result, batch_id: AnalysisResult::CURRENT_SNAPSHOT_BATCH_ID, steamid: user.steamid,
                               model: 'os', metric: 'skill', value: 99.0)

      expect(described_class.call).to eq([])
    end

    it 'filters players below the configured min_games threshold' do
      user = create(:user, steamid: '0:1:77777')
      create(:analysis_result, batch_id: 10, steamid: user.steamid, model: 'player_stats', metric: 'wins', value: 5)
      create(:analysis_result, batch_id: 10, steamid: user.steamid, model: 'player_stats', metric: 'losses', value: 10)
      create(:analysis_result, batch_id: 10, steamid: user.steamid, model: 'os', metric: 'skill', value: 12.5)

      expect(described_class.call(min_games: 25)).to eq([])
    end

    it 'keeps explicit os_btf skill instead of backfilling from os' do
      user = create(:user, steamid: '0:1:88888')
      create(:analysis_result, batch_id: 11, steamid: user.steamid, model: 'os', metric: 'skill', value: 50.0)
      create(:analysis_result, batch_id: 11, steamid: user.steamid, model: 'os_btf', metric: 'skill', value: 40.0)

      ranking = described_class.call.find { |row| row[:user] == user }

      expect(ranking[:skill_os]).to eq(50.0)
      expect(ranking[:skill_os_btf]).to eq(40.0)
    end

    it 'skips rows with un-normalizable steamids' do
      create(:analysis_result, batch_id: 12, steamid: 'not-a-steamid', model: 'os', metric: 'skill', value: 1.0)

      expect(described_class.call).to eq([])
    end

    it 'falls back to default min_games for invalid values' do
      user = create(:user, steamid: '0:1:99998')
      create(:analysis_result, batch_id: 13, steamid: user.steamid, model: 'player_stats', metric: 'wins', value: 20)
      create(:analysis_result, batch_id: 13, steamid: user.steamid, model: 'player_stats', metric: 'losses', value: 10)
      create(:analysis_result, batch_id: 13, steamid: user.steamid, model: 'os', metric: 'skill', value: 2.0)

      expect(described_class.call(min_games: 'invalid').map { |row| row[:user] }).to include(user)
      expect(described_class.call(min_games: 13).map { |row| row[:user] }).to include(user)
    end
  end
end
