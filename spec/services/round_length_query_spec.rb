# frozen_string_literal: true

require 'rails_helper'

describe RoundLengthQuery do
  # No Round factory exists (see MarineTechPathQuery's specs) -- build them
  # straight. Rounds are uniquely indexed on (server_name, start_time), so
  # every one gets its own server name.
  def round(minutes:, result:, map_name: 'ns_eclipse')
    @round_number = (@round_number || 0) + 1
    start_time = Time.zone.parse('2024-01-01 20:00:00') + (@round_number * 1.hour)
    Round.create!(server_name: "Test #{@round_number}", map_name: map_name, start_time: start_time,
                  end_time: start_time + (minutes * 60), result: result)
  end

  def bucket(result, label)
    result[:buckets].find { |row| row.label == label }
  end

  describe '#call' do
    it 'returns every bucket with no rounds when nothing is imported' do
      result = described_class.call

      expect(result[:total_rounds]).to eq(0)
      expect(result[:median_seconds]).to be_nil
      expect(result[:buckets].map(&:rounds)).to all(eq(0))
      expect(result[:buckets].first.label).to eq('0–1')
      expect(result[:buckets].last.label).to eq('60+')
    end

    it 'buckets rounds by length and reports each bucket win rate' do
      3.times { round(minutes: 12.5, result: Round::RESULT_MARINE_WIN) }
      round(minutes: 12.9, result: Round::RESULT_ALIEN_WIN)
      round(minutes: 3, result: Round::RESULT_ALIEN_WIN)

      result = described_class.call

      expect(bucket(result, '12–13').rounds).to eq(4)
      expect(bucket(result, '12–13').marine_wins).to eq(3)
      expect(bucket(result, '12–13').alien_wins).to eq(1)
      expect(bucket(result, '12–13').marine_win_percentage).to eq(75.0)
      expect(bucket(result, '12–13').alien_win_percentage).to eq(25.0)
      expect(bucket(result, '3–4').rounds).to eq(1)
      expect(bucket(result, '11–12').marine_win_percentage).to be_nil
    end

    it 'widens the buckets past 20 minutes and leaves the last one open ended' do
      round(minutes: 21, result: Round::RESULT_MARINE_WIN)
      round(minutes: 32, result: Round::RESULT_MARINE_WIN)
      round(minutes: 180, result: Round::RESULT_ALIEN_WIN)

      result = described_class.call

      expect(bucket(result, '20–22').rounds).to eq(1)
      expect(bucket(result, '30–35').rounds).to eq(1)
      expect(bucket(result, '60+').rounds).to eq(1)
    end

    it 'ignores rounds with no recorded winner or no end time' do
      round(minutes: 10, result: Round::RESULT_MARINE_WIN)
      Round.create!(server_name: 'Unfinished', map_name: 'ns_veil',
                    start_time: Time.zone.parse('2024-05-01 20:00:00'))

      expect(described_class.call[:total_rounds]).to eq(1)
    end

    it 'narrows the buckets to one map without touching the per-map table' do
      round(minutes: 10, result: Round::RESULT_MARINE_WIN, map_name: 'ns_veil')
      round(minutes: 10, result: Round::RESULT_ALIEN_WIN, map_name: 'ns_eclipse')

      result = described_class.call(map: 'ns_veil')

      expect(result[:map]).to eq('ns_veil')
      expect(result[:total_rounds]).to eq(1)
      expect(bucket(result, '10–11').marine_win_percentage).to eq(100.0)
      expect(result[:maps].map { |row| row[:map_name] }).to contain_exactly('ns_veil', 'ns_eclipse')
    end

    it 'reports median length and win rate per map, most played first' do
      round(minutes: 4, result: Round::RESULT_MARINE_WIN, map_name: 'ns_veil')
      round(minutes: 8, result: Round::RESULT_MARINE_WIN, map_name: 'ns_veil')
      round(minutes: 30, result: Round::RESULT_ALIEN_WIN, map_name: 'ns_veil')
      round(minutes: 10, result: Round::RESULT_ALIEN_WIN, map_name: 'ns_eclipse')

      veil, eclipse = described_class.call[:maps]

      expect(veil).to include(map_name: 'ns_veil', rounds: 3, median_seconds: 8 * 60)
      expect(veil[:marine_win_percentage]).to be_within(0.01).of(66.67)
      expect(eclipse).to include(map_name: 'ns_eclipse', rounds: 1, marine_win_percentage: 0.0)
    end

    it 'reports the overall median and win rate for the current selection' do
      round(minutes: 4, result: Round::RESULT_MARINE_WIN)
      round(minutes: 6, result: Round::RESULT_ALIEN_WIN)

      result = described_class.call

      expect(result[:median_seconds]).to eq(5 * 60)
      expect(result[:marine_win_percentage]).to eq(50.0)
    end
  end

  describe '.normalize_map' do
    it 'accepts a map we have rounds for and rejects anything else' do
      round(minutes: 10, result: Round::RESULT_MARINE_WIN, map_name: 'ns_veil')

      expect(described_class.normalize_map('ns_veil')).to eq('ns_veil')
      expect(described_class.normalize_map('ns_nowhere')).to be_nil
      expect(described_class.normalize_map('')).to be_nil
      expect(described_class.normalize_map(nil)).to be_nil
    end
  end
end
