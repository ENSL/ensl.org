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

    def move_up(scope, column = "position")
      n = 0
      objects = self.class.all(conditions: scope, order: column)
      objects.each do |item|
        if item.id == id and n > 0
          old_position = item.read_attribute(:column)
          item.update_attribute(column, objects.fetch(n-1).read_attribute(:column))
          objects.fetch(n-1).update_attribute(column, old_position)
        end
        n = n + 1
      end
    end

    def move_down(scope, column = "position")
      n = 0
      objects = self.class.all(conditions: scope, order: column)
      objects.each do |item|
        if item.id == id and n < (objects.length-1)
          old_position = item.read_attribute(:column)
          item.update_attribute(column, objects.fetch(n+1).read_attribute(:column))
          objects.fetch(n+1).update_attribute(column, old_position)
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