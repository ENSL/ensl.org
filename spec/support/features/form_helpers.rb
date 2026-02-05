module Features
  module FormHelpers
    def fill_form(model, hash)
      hash.each do |attribute, value|
        fill_in attribute_translation(model, attribute), with: value
      end
    end

    def fill_tinymce(element, contents)
      element_id = element.to_s
      contents_js = contents.to_json

      wait = Capybara.default_max_wait_time
      start = Time.now

      # Wait for TinyMCE to be available and set content on its editor
      while Time.now - start < wait
        begin
          present = page.evaluate_script("typeof tinymce !== 'undefined' && tinymce.get(\"#{element_id}\") != null")
        rescue Selenium::WebDriver::Error::WebDriverError
          present = false
        end

        if present
          page.execute_script("tinymce.get(\"#{element_id}\").setContent(#{contents_js})")
          return
        end

        sleep 0.1
      end

      # Fallback: set the underlying textarea (may be hidden)
      if page.has_selector?("textarea##{element_id}", visible: :all)
        page.find("textarea##{element_id}", visible: :all).set(contents)
        return
      end

      raise "TinyMCE editor not available and textarea##{element_id} not found"
    end

    def submit(model, action)
      helper_translation(model, action)
    end

    def attribute_translation(model, attribute)
      I18n.t("activerecord.attributes.#{model}.#{attribute}")
    end

    def helper_translation(model, action)
      I18n.t("helpers.submit.#{model}.#{action}")
    end

    # Helper for selecting datetime values in Rails datetime_select fields
    # @param datetime [Time, DateTime, ActiveSupport::TimeWithZone] The datetime to select
    # @param options [Hash] Options hash
    # @option options [String] :from The base name of the datetime field (e.g., 'Proposed time' or 'match_proposal_proposed_time')
    def select_datetime(datetime, options = {})
      base_id = options[:from] || ''

      # Convert label to field name if needed
      if base_id.present? && !base_id.include?('[')
        begin
          # Try to find the actual field by label
          label = page.find('label', text: base_id, match: :first)
          base_id = label[:for].gsub(/_1i$/, '') if label[:for]
        rescue Capybara::ElementNotFound
          # If label not found, assume it's already a field name
          base_id = base_id.downcase.gsub(' ', '_')
        end
      end

      select datetime.year.to_s, from: "#{base_id}_1i" if datetime.respond_to?(:year)
      select datetime.strftime('%B'), from: "#{base_id}_2i" if datetime.respond_to?(:month)
      select datetime.day.to_s, from: "#{base_id}_3i" if datetime.respond_to?(:day)
      select datetime.strftime('%H'), from: "#{base_id}_4i" if datetime.respond_to?(:hour)

      # Round minutes to nearest 15-minute increment (or custom minute_step if provided)
      return unless datetime.respond_to?(:min)

      minute_step = options[:minute_step] || 15
      minute = datetime.min
      rounded_minute = (minute / minute_step.to_f).round * minute_step
      # Handle wraparound (e.g., if minute is 53 and step is 15, rounds to 60 which becomes 0)
      rounded_minute %= 60
      select rounded_minute.to_s.rjust(2, '0'), from: "#{base_id}_5i"
    end
  end
end
