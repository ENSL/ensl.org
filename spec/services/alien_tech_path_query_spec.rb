# frozen_string_literal: true

require 'rails_helper'

describe AlienTechPathQuery do
  def round_with_chambers(result:, chambers:)
    @round_number = (@round_number || 0) + 1
    start_time = Time.zone.parse('2024-01-01 20:00:00') + (@round_number * 1.hour)
    round = Round.create!(server_name: 'Test', map_name: 'ns_eclipse', start_time: start_time,
                          end_time: start_time + 20.minutes, result: result)
    chambers.each_with_index do |chamber, index|
      LogLine.create!(round: round, event_type: 'structure_built', param1: chamber,
                      created_at: start_time + index.minutes)
    end
    round
  end

  it 'uses the first build of each chamber as the ordered hive choice' do
    round_with_chambers(result: Round::RESULT_ALIEN_WIN,
                        chambers: %w[defensechamber defensechamber movementchamber sensorychamber])

    row = described_class.call(path_length: nil, min_rounds: 1).find do |result|
      result[:path] == %w[defensechamber movementchamber sensorychamber]
    end

    expect(row).to include(rounds: 1, wins: 1, losses: 0)
  end

  it 'excludes non-chamber structures and scores alien wins' do
    round_with_chambers(result: Round::RESULT_ALIEN_WIN,
                        chambers: %w[alienresourcetower offensechamber movementchamber])
    round_with_chambers(result: Round::RESULT_MARINE_WIN, chambers: %w[movementchamber])

    row = described_class.call(path_length: 1, min_rounds: 1).find { |result| result[:path] == ['movementchamber'] }

    expect(row).to include(rounds: 2, wins: 1, losses: 1)
  end
end
