# frozen_string_literal: true

require 'rails_helper'

describe RoundActivityQuery do
  def activity(day:, hour:, rounds:)
    create(:analysis_result, batch_id: AnalysisResult::CURRENT_SNAPSHOT_BATCH_ID,
                             steamid: day.to_s, model: 'time_of_week', metric: 'round_count',
                             milestone: hour, value: rounds)
  end

  describe '#call' do
    it 'returns a dense, empty grid when there are no rounds' do
      result = described_class.call

      expect(result[:total_rounds]).to eq(0)
      expect(result[:busiest_cell]).to be_nil
      expect(result[:days].size).to eq(7)
      expect(result[:days].map(&:cells).map(&:size)).to all(eq(24))
      expect(result[:hour_totals]).to eq(Array.new(24, 0))
    end

    it 'pivots the Sunday-first import into Monday-first weekday slots' do
      activity(day: 6, hour: 20, rounds: 2)
      activity(day: 1, hour: 21, rounds: 1)

      result = described_class.call
      saturday = result[:days].find { |day| day.name == 'Saturday' }
      monday = result[:days].find { |day| day.name == 'Monday' }

      expect(result[:days].map(&:name).first).to eq('Monday')
      expect(saturday.cells[20].rounds).to eq(2)
      expect(monday.cells[21].rounds).to eq(1)
      expect(saturday.total).to eq(2)
      expect(result[:total_rounds]).to eq(3)
    end

    it 'reports the busiest slot and scales every cell against it' do
      activity(day: 6, hour: 20, rounds: 3)
      activity(day: 1, hour: 21, rounds: 1)

      result = described_class.call
      saturday = result[:days].find { |day| day.name == 'Saturday' }
      monday = result[:days].find { |day| day.name == 'Monday' }

      expect(result[:busiest_cell]).to eq(day_name: 'Saturday', hour: 20, count: 3)
      expect(saturday.cells[20].share).to eq(1.0)
      expect(monday.cells[21].share).to be_within(0.001).of(1.0 / 3)
      expect(monday.cells[0].share).to eq(0.0)
    end

    it 'collapses the weekday away for the hour-of-day totals' do
      activity(day: 6, hour: 20, rounds: 1)
      activity(day: 1, hour: 20, rounds: 1)

      expect(described_class.call[:hour_totals][20]).to eq(2)
    end

    it 'uses only the current imported snapshot' do
      activity(day: 6, hour: 20, rounds: 2)
      create(:analysis_result, batch_id: 99, steamid: '6', model: 'time_of_week',
                               metric: 'round_count', milestone: 20, value: 10)

      expect(described_class.call[:total_rounds]).to eq(2)
    end
  end
end
