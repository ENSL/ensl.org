module Features
  module FormHelpers
    def fill_form(model, hash)
      hash.each do |attribute, value|
        fill_in attribute_translation(model, attribute), :with => value
      end
    end

    def fill_tinymce(element, contents)
      page.execute_script("$('#{element}').tinymce().setContent('#{contents}')")
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