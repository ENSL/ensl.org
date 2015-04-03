class GoogleCalendar
  attr_accessor :timezone

  def initialize(id, timezone_offset = Time.zone.name)
    @id = id
    @timezone_offset = timezone_offset
  end

  def summary
    list.summary
  end

  def timezone
    list.timezone
  end

  def events
    list.events
  end

  def upcoming
    events.select do |event|
      event.start >= (Time.zone.now - 2.hours)
    end
  end

  def list
    @list ||= GoogleCalendar::Request.events_list(@id, @timezone_offset)
  end
end

class GoogleCalendar
  class Request
    BASE_URL = "https://www.googleapis.com/calendar/v3/calendars"
    EVENTS_ENDPOINT = "events"

    def self.events_list(id, timezone_offset)
      request = self.new(id, EVENTS_ENDPOINT)
      GoogleCalendar::EventList.new(request.parsed_response, timezone_offset)
    end

    def initialize(id, endpoint)
      @id = id
      @endpoint = endpoint
      @response = get_data
    end

    def parsed_response
      JSON.parse(@response.body)
    end

    private

    def get_data
      Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
        Faraday.get(request_url)
      end
    end

    def cache_key
      "/google_calendar/#{@id}/#{@endpoint}"
    end

    def request_url
      "#{BASE_URL}/#{@id}/#{@endpoint}/?key=#{ENV['GOOGLE_API_KEY']}"
    end
  end

  class EventList
    attr_reader :summary, :events, :timezone

    def initialize(list, timezone_offset)
      @list = list
      @timezone_offset = timezone_offset

      parse_list
      parse_events
    end

    private

    def parse_list
      @summary = @list["summary"]
      @timezone = @list["timeZone"]
    end

    def parse_events
      @events = @list["items"].map do |item|
        GoogleCalendar::Event.new(item, @timezone_offset)
      end
    end
  end

  class Event
    def initialize(entry, timezone_offset)
      @entry = entry
      @timezone_offset = timezone_offset
    end

    def start
      @entry["start"]["dateTime"].to_datetime.in_time_zone(@timezone_offset)
    end

    def end
      @entry["end"]["dateTime"].to_datetime.in_time_zone(@timezone_offset)
    end

    def formatted_summary
      summary.gsub(/(http\:\/\/)(.*[^)])/i, '<a href="\1\2">\2</a>').html_safe
    end

    def [](key)
      @entry[key]
    end

    def method_missing(method)
      self[method.to_s]
    end
  end
end