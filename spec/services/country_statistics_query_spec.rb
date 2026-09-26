# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CountryStatisticsQuery do
  describe '.call' do
    it 'keeps countries with more than ten accounts and combines the rest into Other countries' do
      11.times { create(:user, country: 'US') }
      create(:user, country: 'CA')
      create(:user, country: '')
      create(:user, country: nil)

      rows = described_class.call[:all_players]

      expect(rows.map { |row| [row[:country_code], row[:players]] })
        .to contain_exactly(['US', 11], ['Other countries', 3])
    end

    it 'uses distinct round participants with at least five players and ranking-scale DL skill aggregates' do
      united_states_player = create(:user, steamid: '0:1:101', country: 'US')
      second_united_states_player = create(:user, steamid: '0:1:102', country: 'US')
      canadian_player = create(:user, steamid: '0:1:103', country: 'CA')
      create(:user, steamid: '0:1:104', country: '')

      round = Round.create!(server_name: 'Country stats one', start_time: Time.zone.parse('2026-01-01 12:00:00'))
      another_round = Round.create!(server_name: 'Country stats two',
                                    start_time: Time.zone.parse('2026-01-02 12:00:00'))
      Rounder.create!(round: round, steamid: "STEAM_#{united_states_player.steamid}", team: 1, share: 1.0)
      Rounder.create!(round: another_round, steamid: "STEAM_#{united_states_player.steamid}", team: 1, share: 1.0)
      Rounder.create!(round: round, steamid: "STEAM_#{second_united_states_player.steamid}", team: 1, share: 1.0)
      Rounder.create!(round: round, steamid: "STEAM_#{canadian_player.steamid}", team: 1, share: 1.0)
      3.times do |number|
        player = create(:user, steamid: "0:1:11#{number}", country: 'US')
        Rounder.create!(round: round, steamid: "STEAM_#{player.steamid}", team: 1, share: 1.0)
      end

      create(:analysis_result, batch_id: 1, steamid: united_states_player.steamid, model: 'dl', metric: 'skill',
                               value: 10.0)
      create(:analysis_result, batch_id: 1, steamid: second_united_states_player.steamid, model: 'dl', metric: 'skill',
                               value: 30.0)
      create(:analysis_result, batch_id: 1, steamid: canadian_player.steamid, model: 'dl', metric: 'skill', value: 50.0)
      create(:analysis_result, batch_id: 2, steamid: "STEAM_#{united_states_player.steamid}", model: 'DL',
                               metric: 'skill', value: 20.0)
      create(:analysis_result, batch_id: 2, steamid: "STEAM_#{second_united_states_player.steamid}", model: 'DL',
                               metric: 'skill', value: 40.0)

      rows = described_class.call[:round_skill_players].index_by { |row| row[:country] }
      per_player_rows = described_class.call[:skill_per_player_players].index_by { |row| row[:country] }

      expect(rows.keys).to contain_exactly('US')
      expect(rows['US']).to include(players: 5, average_skill: 301_000.0, top_ten_average_skill: 301_000.0,
                                    skill_per_player: 60_200.0)
      expect(per_player_rows).to eq(rows)
    end

    it 'averages only the ten highest DL skills for the top-ten country metric' do
      round = Round.create!(server_name: 'Country top ten', start_time: Time.zone.parse('2026-01-04 12:00:00'))
      players = (1..11).map do |number|
        player = create(:user, steamid: "0:1:3#{number}", country: 'DE')
        Rounder.create!(round: round, steamid: "STEAM_#{player.steamid}", team: 1, share: 1.0)
        create(:analysis_result, batch_id: 1, steamid: player.steamid, model: 'dl', metric: 'skill', value: number.to_f)
        player
      end

      row = described_class.call[:round_skill_players].find { |country| country[:country] == 'DE' }

      expect(players.size).to eq(11)
      expect(row).to include(players: 11, average_skill: 61_000.0, top_ten_average_skill: 66_000.0)
    end

    it 'sorts the skill charts by their displayed metric in descending order' do
      round = Round.create!(server_name: 'Country ordering', start_time: Time.zone.parse('2026-01-05 12:00:00'))

      { 'DE' => [10, 30.0], 'US' => [5, 20.0] }.each do |country, (player_count, skill)|
        player_count.times do |number|
          player = create(:user, steamid: "0:1:#{country == 'DE' ? 4 : 5}#{number}", country: country)
          Rounder.create!(round: round, steamid: "STEAM_#{player.steamid}", team: 1, share: 1.0)
          create(:analysis_result, batch_id: 1, steamid: player.steamid, model: 'dl', metric: 'skill', value: skill)
        end
      end

      report = described_class.call

      expect(report[:round_skill_players].map { |row| row[:country] }).to eq(%w[DE US])
      expect(report[:skill_per_player_players].map { |row| row[:country] }).to eq(%w[US DE])
    end
  end
end
