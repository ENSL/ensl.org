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
  end
end
