# frozen_string_literal: true

begin
  require 'google/apis/calendar_v3'
  CALENDAR = Google::Apis::CalendarV3

  class GoogleCalendar
    def initialize(calendar_id, timezone_offset = Time.zone.name)
      @id = calendar_id
      @timezone_offset = timezone_offset
      @events = nil
      @service = CALENDAR::CalendarService.new
      # @service.authorization = CALENDAR::AUTH_CALENDAR # change this if write access needed
      @service.key = ENV['GOOGLE_API_KEY']
      query_events
    end

    def upcoming
      @events&.reject do |event|
        nsltv_regex =~ event.summary
      end
    end

    def upcoming_nsltv
      @events&.select do |event|
        nsltv_regex =~ event.summary
      end
    end

    def query_events
      list = nil
      @events.nil? and @service.list_events(@id, time_zone: ActiveSupport::TimeZone::MAPPING[@timezone_offset],
                                                 time_min: 2.hours.ago.utc.iso8601) do |result, err|
        if err
          if defined?(Rails) && Rails.configuration.x.respond_to?(:debug_prints) && Rails.configuration.x.debug_prints
            Rails.logger.debug(err.inspect)
          end
        else
          list = result
        end
      end
      @events = list&.items&.sort_by { |event| event.start.date_time }
    end

    def nsltv_regex
      /\[NSLTV\]/i
    end
  end
rescue LoadError
  class GoogleCalendar
  end
end
