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
      event.start >= (Time.zone.now - 2.hours) &&
        (not event.nsltv_regex =~ event.summary)
    end
  end

  def upcoming_nsltv
    events.select do |event|
      event.start >= (Time.zone.now - 2.hours) &&
        event.nsltv_regex =~ (event.summary)
    end
  end

  def list
    @list ||= GoogleCalendar::Request.events_list(@id, @timezone_offset)
  end
end

class GoogleCalendar
  class Request
    BASE_URL = "https://www.googleapis.com/"
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
        if Rails.env.development?
          conn = Faraday.new(BASE_URL, ssl: {verify: false})
        else
          conn = Faraday.new(BASE_URL)
        end
        conn.get(request_url)
      end
    end

    def cache_key
      "/google_calendar/#{@id}/#{@endpoint}"
    end

    def request_url
      #The default number of events pulled is 250.
      #We reached that number and events didn't show any more.
      #So now I filter all events that have a start time
      #that is longer ago then 7 days.
      #Alternative: maxResults=2500
      time_min = (Time.now - 7.days).utc.iso8601
      "calendar/v3/calendars/#{@id}/#{@endpoint}/?key=#{ENV['GOOGLE_API_KEY']}&timeMin=#{time_min}"
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

    def nsltv_regex
      /\[NSLTV\]/i
    end

    def formatted_summary
      summary.gsub(/(http\:\/\/)(.*[^)])/i, '<a href="\1\2">\2</a>').
        gsub(nsltv_regex, '').html_safe
    end

    def [](key)
      @entry[key]
    end

    def method_missing(method)
      self[method.to_s]
    end
  end
end
