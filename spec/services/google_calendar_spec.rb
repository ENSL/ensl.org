# frozen_string_literal: true

require 'rails_helper'
require 'ostruct'

RSpec.describe GoogleCalendar do
  describe '#query_events and filters' do
    let(:service) { instance_double(CALENDAR::CalendarService) }

    before do
      allow(CALENDAR::CalendarService).to receive(:new).and_return(service)
      allow(service).to receive(:key=)
    end

    it 'sorts fetched events by start date time' do
      later = OpenStruct.new(summary: 'Later',
                             start: OpenStruct.new(date_time: Time.zone.parse('2026-01-01 12:00:00 UTC')))
      earlier = OpenStruct.new(summary: 'Earlier',
                               start: OpenStruct.new(date_time: Time.zone.parse('2026-01-01 10:00:00 UTC')))
      result = OpenStruct.new(items: [later, earlier])

      allow(service).to receive(:list_events) do |_id, _opts, &block|
        block.call(result, nil)
      end

      calendar = described_class.new('calendar-id', 'UTC')

      expect(calendar.upcoming.map(&:summary)).to eq(%w[Earlier Later])
    end

    it 'returns non-NSLTV events from upcoming and NSLTV events from upcoming_nsltv' do
      nsltv = OpenStruct.new(summary: '[NSLTV] Stream',
                             start: OpenStruct.new(date_time: Time.zone.parse('2026-01-01 11:00:00 UTC')))
      match = OpenStruct.new(summary: 'Match Event',
                             start: OpenStruct.new(date_time: Time.zone.parse('2026-01-01 12:00:00 UTC')))
      result = OpenStruct.new(items: [nsltv, match])

      allow(service).to receive(:list_events) do |_id, _opts, &block|
        block.call(result, nil)
      end

      calendar = described_class.new('calendar-id', 'UTC')

      expect(calendar.upcoming.map(&:summary)).to eq(['Match Event'])
      expect(calendar.upcoming_nsltv.map(&:summary)).to eq(['[NSLTV] Stream'])
    end

    it 'keeps events empty when the API callback returns an error' do
      allow(service).to receive(:list_events) do |_id, _opts, &block|
        block.call(nil, StandardError.new('calendar failure'))
      end

      calendar = described_class.new('calendar-id', 'UTC')

      expect(calendar.upcoming).to be_nil
      expect(calendar.upcoming_nsltv).to be_nil
    end

    it 'does not call list_events again once events are already loaded' do
      event = OpenStruct.new(summary: 'Loaded once',
                             start: OpenStruct.new(date_time: Time.zone.parse('2026-01-01 12:00:00 UTC')))
      result = OpenStruct.new(items: [event])

      allow(service).to receive(:list_events) do |_id, _opts, &block|
        block.call(result, nil)
      end

      calendar = described_class.new('calendar-id', 'UTC')
      calendar.query_events

      expect(service).to have_received(:list_events).once
    end
  end

  describe '#nsltv_regex' do
    it 'matches NSLTV marker case-insensitively' do
      service = instance_double(CALENDAR::CalendarService)
      allow(service).to receive(:key=)
      allow(service).to receive(:list_events)
      allow(CALENDAR::CalendarService).to receive(:new).and_return(service)
      calendar = described_class.new('calendar-id', 'UTC')

      expect('[nsltv] event').to match(calendar.nsltv_regex)
      expect('regular event').not_to match(calendar.nsltv_regex)
    end
  end
end
