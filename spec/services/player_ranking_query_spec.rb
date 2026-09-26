# frozen_string_literal: true

require 'rails_helper'

describe PlayerRankingQuery do
  def add_player(batch_id:, source_steamid:, user_id:, skills: {}, wins: nil, losses: nil, win_ratio: nil)
    values = { wins: wins, losses: losses, win_ratio: win_ratio }.compact
    create_analysis_user(batch_id: batch_id, user_id: user_id, steam_id: source_steamid, **values)
    skills.each do |model, skill|
      create_analysis_skill(batch_id: batch_id, model: model, user_id: user_id, skill: skill)
    end
  end

  describe '#call' do
    it 'returns an empty array when there are no historical batches' do
      expect(described_class.call).to eq([])
    end

    it 'pivots the latest batch into one row per known player' do
      user = create(:user, steamid: '0:1:11111')

      add_player(batch_id: 1, source_steamid: user.steamid, user_id: 1, skills: { os: 10.0 })
      add_player(batch_id: 2, source_steamid: user.steamid, user_id: 1, skills: { os: 25.5, dl: 30.0 },
                 wins: 12, losses: 4, win_ratio: 0.75)
      add_player(batch_id: 2, source_steamid: '0:1:99999', user_id: 2, skills: { os: 5.0 })

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

      add_player(batch_id: 3, source_steamid: 'STEAM_0:1:33333', user_id: 3, skills: { os: 22.0, dl: 28.5 }, wins: 9)

      ranking = described_class.call.find { |row| row[:user] == user }

      expect(ranking).not_to be_nil
      expect(ranking[:skill_os]).to eq(22.0)
      expect(ranking[:skill_dl]).to eq(28.5)
      expect(ranking[:wins]).to eq(9)
    end

    it 'excludes current-state snapshot rows (batch_id 0)' do
      user = create(:user, steamid: '0:1:22222')
      add_player(batch_id: AnalysisResult::CURRENT_SNAPSHOT_BATCH_ID, source_steamid: user.steamid,
                 user_id: 4, skills: { os: 99.0 })

      expect(described_class.call).to eq([])
    end

    it 'filters players below the configured min_games threshold' do
      user = create(:user, steamid: '0:1:77777')
      add_player(batch_id: 10, source_steamid: user.steamid, user_id: 10, skills: { os: 12.5 }, wins: 5, losses: 10)

      expect(described_class.call(min_games: 25)).to eq([])
    end

    it 'keeps explicit os_btf skill instead of backfilling from os' do
      user = create(:user, steamid: '0:1:88888')
      add_player(batch_id: 11, source_steamid: user.steamid, user_id: 11,
                 skills: { os: 50.0, os_btf: 40.0 })

      ranking = described_class.call.find { |row| row[:user] == user }

      expect(ranking[:skill_os]).to eq(50.0)
      expect(ranking[:skill_os_btf]).to eq(40.0)
    end

    it 'skips rows with un-normalizable steamids' do
      add_player(batch_id: 12, source_steamid: 'not-a-steamid', user_id: 12, skills: { os: 1.0 })

      expect(described_class.call).to eq([])
    end

    it 'falls back to default min_games for invalid values' do
      user = create(:user, steamid: '0:1:99998')
      add_player(batch_id: 13, source_steamid: user.steamid, user_id: 13,
                 skills: { os: 2.0 }, wins: 50, losses: 30)

      expect(described_class.call(min_games: 'invalid').map { |row| row[:user] }).to include(user)
      expect(described_class.call(min_games: 13).map { |row| row[:user] }).to include(user)
    end
  end
end
