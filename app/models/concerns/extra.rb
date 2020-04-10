module Extra
  extend ActiveSupport::Concern

  CODING_HTML = 0
  CODING_BBCODE = 1
  CODING_MARKDOWN = 2

  included do
    def codings
      {
        CODING_HTML => "Plain HTML",
        CODING_BBCODE => "BBCode",
        CODING_MARKDOWN => "Markdown"
      }
    end

    def check_params(params, filter)
      (params.instance_of?(Array) ? params : params.keys).each do |key|
        return false unless filter.include? key.to_sym
      end
      return true
    end

    def error_messages
      self.errors.full_messages.uniq
    end

    def bbcode_to_html(text)
      Sanitize.clean(text.to_s).bbcode_to_html.gsub(/\n|\r\n/, "<br>").html_safe
    end

    def cleanup_string(str, len=20)
      str = str.gsub(/[^0-9A-Za-z\-_]/, '')
      if str.length > len
        str = str.to_s[0, len]
      end
      return str
    end

    def move_up(objects, column = "position")
      n = 0
      # the objects need to be assigned before loop or the order is not right
      (objects = objects.order(column)).each_with_index do |item, i|
        if item.id == id and n > 0
          old_position = item[column]
          item.update_attribute(column, objects[i-1][column])
          objects[i-1].update_attribute(column, old_position)
        end
        n = n + 1
      end
    end

    def move_down(objects, column = "position")
      n = 0
      (objects = objects.order(column)).each_with_index do |item, i|
        if item.id == id and n < (objects.length-1)
          old_position = item[column]
          item.update_attribute(column, objects[n+1][column])
          objects[n+1].update_attribute(column, old_position)
        end
        n = n + 1
      end
    end

    def can_show? cuser
      true
    end

    def can_create? cuser
      true
    end

    def can_update? cuser
      true
    end

    def can_destroy? cuser
      true
    end
  end
end