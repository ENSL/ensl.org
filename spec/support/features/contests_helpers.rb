# frozen_string_literal: true

module Features
  module ContestsHelpers
    def select_match_datetime(value)
      select_option_by_value('match_match_time_1i', value.year)
      select_option_by_value('match_match_time_2i', value.strftime('%B'))
      select_option_by_value('match_match_time_3i', value.day)
      select_option_by_value('match_match_time_4i', value.strftime('%H'))
      select_option_by_value('match_match_time_5i', value.strftime('%M'))
    end

    # Helper to select options by value, with fallback for zero-padded values
    # This is needed because Rails date/time selects can have options like "1" or "01"
    # depending on the locale and configuration
    def select_option_by_value(select_id, value)
      select value.to_s, from: select_id
    rescue Capybara::ElementNotFound
      select value.to_s.rjust(2, '0'), from: select_id
    end
  end
end
