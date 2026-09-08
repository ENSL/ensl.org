# frozen_string_literal: true

require 'rails_helper'

describe MarineTechPathQuery do
  # No factories exist for Round/LogLine (see the round timeline specs) --
  # build them straight, one round per opening order. Each round needs its own
  # start_time: rounds are uniquely indexed on (server_name, start_time).
  def round_with_research(result:, researches:)
    @round_number = (@round_number || 0) + 1
    start_time = Time.zone.parse('2024-01-01 20:00:00') + (@round_number * 1.hour)
    round = Round.create!(server_name: 'Test', map_name: 'ns_eclipse', start_time: start_time,
                          end_time: start_time + 20.minutes, result: result)
    researches.each_with_index do |research, index|
      LogLine.create!(round: round, event_type: 'research_start', param1: research,
                      created_at: start_time + index.minutes)
    end
    round
  end

  describe '#call' do
    it 'returns an empty array when no rounds have research events' do
      expect(described_class.call).to eq([])
    end

    it 'groups rounds by opening order and counts wins and losses' do
      2.times do
        round_with_research(result: Round::RESULT_MARINE_WIN,
                            researches: %w[research_armorl1 research_weaponsl1 research_phasetech])
      end
      round_with_research(result: Round::RESULT_ALIEN_WIN,
                          researches: %w[research_armorl1 research_weaponsl1 research_phasetech])

      row = described_class.call(path_length: 3, min_rounds: 1).find do |result|
        result[:path] == %w[research_armorl1 research_weaponsl1 research_phasetech]
      end

      expect(row[:path]).to eq(%w[research_armorl1 research_weaponsl1 research_phasetech])
      expect(row).to include(rounds: 3, wins: 2, losses: 1)
      expect(row[:win_ratio]).to be_within(0.01).of(66.67)
    end

    it 'treats a different research order as a different path' do
      round_with_research(result: Round::RESULT_MARINE_WIN, researches: %w[research_armorl1 research_weaponsl1])
      round_with_research(result: Round::RESULT_ALIEN_WIN, researches: %w[research_weaponsl1 research_armorl1])

      paths = described_class.call(path_length: 2, min_rounds: 1).map { |row| row[:path] }

      expect(paths).to include(%w[research_armorl1], %w[research_weaponsl1],
                               %w[research_armorl1 research_weaponsl1],
                               %w[research_weaponsl1 research_armorl1])
    end

    it 'ignores distress beacons and repeated starts of the same research' do
      round_with_research(result: Round::RESULT_MARINE_WIN,
                          researches: %w[research_distressbeacon research_armorl1 research_distressbeacon
                                         research_armorl1 research_weaponsl1])

      row = described_class.call(path_length: 2, min_rounds: 1).find do |result|
        result[:path] == %w[research_armorl1 research_weaponsl1]
      end

      expect(row[:path]).to eq(%w[research_armorl1 research_weaponsl1])
    end

    it 'includes Catalysts as an opening research' do
      round_with_research(result: Round::RESULT_MARINE_WIN,
                          researches: %w[research_catalysts research_armorl1])

      paths = described_class.call(path_length: 1, min_rounds: 1).map { |row| row[:path] }

      expect(paths).to include(%w[research_catalysts])
    end

    it 'retains every opening prefix when the path length is uncapped' do
      round_with_research(result: Round::RESULT_MARINE_WIN,
                          researches: %w[research_armorl1 research_weaponsl1 research_phasetech])

      paths = described_class.call(path_length: nil, min_rounds: 1).map { |row| row[:path] }

      expect(paths).to include(%w[research_armorl1], %w[research_armorl1 research_weaponsl1],
                               %w[research_armorl1 research_weaponsl1 research_phasetech])
    end

    it 'treats the path length as a maximum, keeping shorter paths as they are' do
      round_with_research(result: Round::RESULT_MARINE_WIN, researches: %w[research_armorl1])

      row = described_class.call(path_length: 3, min_rounds: 1).find do |result|
        result[:path] == %w[research_armorl1]
      end

      expect(row[:path]).to eq(%w[research_armorl1])
    end

    it 'skips rounds with no recorded result' do
      round_with_research(result: nil, researches: %w[research_armorl1 research_weaponsl1])

      expect(described_class.call(path_length: 2, min_rounds: 1)).to eq([])
    end

    it 'drops paths taken in fewer rounds than min_rounds' do
      round_with_research(result: Round::RESULT_MARINE_WIN, researches: %w[research_armorl1 research_weaponsl1])

      expect(described_class.call(path_length: 2, min_rounds: 5)).to eq([])
    end

    it 'orders by win ratio descending' do
      round_with_research(result: Round::RESULT_MARINE_WIN, researches: %w[research_armorl1 research_weaponsl1])
      round_with_research(result: Round::RESULT_ALIEN_WIN, researches: %w[research_weaponsl1 research_armorl1])

      win_ratios = described_class.call(path_length: 2, min_rounds: 1).map { |row| row[:win_ratio] }

      expect(win_ratios).to eq([100.0, 100.0, 0.0, 0.0])
    end

    it 'caps the number of returned paths at the requested limit' do
      round_with_research(result: Round::RESULT_MARINE_WIN, researches: %w[research_armorl1 research_weaponsl1])
      round_with_research(result: Round::RESULT_ALIEN_WIN, researches: %w[research_weaponsl1 research_armorl1])

      expect(described_class.call(path_length: 2, min_rounds: 1, result_limit: 1).size).to eq(1)
    end

    it 'returns every qualifying path when the row limit is uncapped' do
      round_with_research(result: Round::RESULT_MARINE_WIN, researches: %w[research_armorl1 research_weaponsl1])
      round_with_research(result: Round::RESULT_ALIEN_WIN, researches: %w[research_weaponsl1 research_armorl1])

      expect(described_class.call(path_length: 2, min_rounds: 1, result_limit: nil).size).to eq(4)
    end
  end

  describe '#rounds_analysed' do
    it 'counts every round with a research, before the min_rounds cutoff' do
      round_with_research(result: Round::RESULT_MARINE_WIN, researches: %w[research_armorl1 research_weaponsl1])
      round_with_research(result: Round::RESULT_MARINE_WIN, researches: %w[research_armorl1])

      query = described_class.new(path_length: 2, min_rounds: 50)

      expect(query.call).to eq([])
      expect(query.rounds_analysed).to eq(2)
    end
  end

  describe 'path counts' do
    it 'reports how many distinct paths exist and how many clear the minimum' do
      2.times { round_with_research(result: Round::RESULT_MARINE_WIN, researches: %w[research_armorl1]) }
      round_with_research(result: Round::RESULT_ALIEN_WIN, researches: %w[research_weaponsl1])

      query = described_class.new(path_length: 1, min_rounds: 2)

      expect(query.paths_found).to eq(2)
      expect(query.paths_above_minimum).to eq(1)
    end
  end

  describe 'parameter normalization' do
    it 'falls back to defaults for unsupported values' do
      expect(described_class.normalize_path_length(99)).to eq(described_class::DEFAULT_PATH_LENGTH)
      expect(described_class.normalize_path_length('4')).to eq(4)
      expect(described_class.normalize_path_length('all')).to be_nil
      expect(described_class.normalize_min_rounds('nonsense')).to eq(described_class::DEFAULT_MIN_ROUNDS)
      expect(described_class.normalize_min_rounds('25')).to eq(25)
      expect(described_class.normalize_result_limit(999)).to eq(described_class::DEFAULT_RESULT_LIMIT)
      expect(described_class.normalize_result_limit('50')).to eq(50)
      expect(described_class.normalize_result_limit('all')).to be_nil
    end
  end
end
