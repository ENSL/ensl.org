module ApplicationHelper
  def full_title(page_title)
    base_title = "NSL"
    base_title << " " + Rails.env.upcase unless Rails.env.production?

    if page_title.empty?
      base_title
    else
      "#{base_title} | #{page_title}"
    end
  end

  def active_theme
    if cuser && cuser.profile
      cuser.current_layout
    else
      'default'
    end
  end

  def theme_stylesheet_link_tag
    stylesheet_link_tag "themes/#{active_theme}/theme"
  end

  def namelink(model, length = nil)
    return if model.nil?
    model = case model.class.to_s
            when "DataFile"
              model.movie ? model.movie : model
            when "Comment"
              model.commentable
            when "Post"
              model.topic
            else
              model
            end
    str = model.to_s

    # Reduce length of too long model names
    if length and str.length > length
      link_to(str.to_s[0, length] + "...", model, class: model.class.to_s.downcase)
    else
      link_to(str, model, class: model.class.to_s.downcase)
    end
  end

  def directory_links(directory)
    output = ""
    Directory.directory_traverse(directory).reverse_each do |dir|
      output << namelink(dir) + "\n"
      unless dir == directory
        output << " &raquo; \n"
      end
    end
    output.html_safe
  end

  def shorten str, length
    if length and str and str.to_s.length > length
      str = str.to_s[0, length] + "..."
    end
    str
  end

  def longtime time
    printtime time, "%d %B %y %H:%M"
  end

  def longertime time
    printtime time, "%e %B %Y - %H:%M %Z"
  end

  def shorttime time
    printtime time, "%d/%b/%y %H:%M"
  end

  def shortdate time
    printtime time, "%d %b %y"
  end

  def longdate time
    printtime time, "%e %B %Y"
  end

  def printtime time, format
    return unless time

    content_tag(:span, style: 'font-style: italic') do
      Time.use_zone(timezone_offset) { time.strftime(format) }
    end
  end

  # Print the attributes from the list
  def cascade model, list
    return "" if model.nil?

    out = list.map do |element|
      name = key = element
      item = ""
      result = ""

      if element.instance_of?(Array)
        name = element[0]
        key = element[1]
      end

      if m = key.to_s.match(/^(.*)_b$/)
        name = m[1]
        key = m[1]
      end        

      begin
        str = eval("model.#{key}")
      rescue
        next
      end

      next if str == "" or str.nil?

      if model[key].instance_of?(Time) or model[key].instance_of?(ActiveSupport::TimeWithZone)
        # result << shorttime(str)
        result << model[key].to_formatted_s(:long_ordinal)
      elsif element.instance_of?(Symbol)
        result << namelink(str)
      elsif key.to_s.match(/^(.*)_b$/)
        result << str.bbcode_to_html
      else
        result << h(str)
      end

      item << content_tag(:dt) do
        "#{name.to_s.capitalize.gsub(/_s/, '').gsub(/_/, ' ')}".html_safe
      end
      item << content_tag(:dd) do
        result.html_safe
      end

      item
    end

    content_tag(:dl) do
      out.join.html_safe
    end
  end

  def abslink text, url
    raw link_to text, url
  end

  def flag country
    if country and country.to_s.size > 0
      image_tag 'shared/blank.gif', class: "flag flag-#{country.downcase}"
    else
      image_tag 'shared/blank.gif', class: 'flag'
    end
  end

  def add_comments(object)
    @comment = Comment.new(commentable: object)
    @comments = object.comments.ordered.with_userteam

    return_here
    render partial: "comments/index"
  end

  def bbcode
    link_to "(BBCode)", article_url(id: 536)
  end

  def sortable(column, title = nil)
    title ||= column.titleize
    css_class = (column == sort_column) ? "current #{sort_direction}" : nil
    direction = (column == sort_column && sort_direction == "asc") ? "desc" : "asc"
    link_to title, { sort: column, direction: direction }, { class: css_class }
  end

  def link_to_remove_fields(name, f)
    f.hidden_field(:_destroy) + link_to_function(name, "remove_fields(this)")
  end

  # FIXME: this won't work.
  def link_to_add_fields(name, f, association)
    new_object = f.object.class.reflect_on_association(association).klass.new
    fields = f.fields_for(association, new_object, child_index: "new_#{association}") do |builder|
      render(association.to_s.singularize, f: builder)
    end
    link_to_function(name, ("add_fields(this, '#{association}', '#{escape_javascript(fields)}')"))
  end

  def timezone_offset
    if @cuser
      @cuser.time_zone
    else
      Time.zone.name
    end
  end

  def calendar
    @calendar ||= GoogleCalendar.new(ENV['GOOGLE_CALENDAR_ID'], timezone_offset)
  end

  def event_start_time event
    event.start.date_time.to_datetime.in_time_zone(timezone_offset)
  end

  def upcoming_matches
    ENV['GOOGLE_CALENDAR'] == "disabled" ? (calendar.upcoming || []) : []
  end

  def upcoming_nsltv
    ENV['GOOGLE_CALENDAR'] == "disabled" ? (calendar.upcoming || []) : []
  end

  def gathers_url
    if Rails.env.production?
      "https://gathers.ensl.org"
    else
      "https://gathers.staging.ensl.org"
    end
  end
end
