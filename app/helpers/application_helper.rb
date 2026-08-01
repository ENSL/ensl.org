# frozen_string_literal: true

module ApplicationHelper
  def full_title(page_title)
    base_title = +'NSL'
    base_title << " #{Rails.env.upcase}" unless Rails.env.production?

    if page_title.empty?
      base_title
    else
      "#{base_title} | #{page_title}"
    end
  end

  def active_theme
    if cuser&.profile
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
            when 'DataFile'
              model.movie || model
            when 'Comment'
              model.commentable
            when 'Post'
              model.topic
            else
              model
            end
    str = model.to_s

    options = { class: model.class.to_s.downcase }
    options[:data] = { turbo_frame: '_top' } if model.is_a?(User)

    # Reduce length of too long model names
    if length && (str.length > length)
      link_to("#{str.to_s[0, length]}...", model, options)
    else
      link_to(str, model, options)
    end
  end

  def directory_links(directory)
    links = []
    Directory.directory_traverse(directory).reverse_each do |dir|
      links << namelink(dir)
      links << "\n"
      links << " \u00BB \n" unless dir == directory
    end

    safe_join(links)
  end

  def shorten(str, length)
    str = "#{str.to_s[0, length]}..." if length && str && (str.to_s.length > length)
    str
  end

  def longtime(time)
    printtime time, '%d %B %y %H:%M'
  end

  def longertime(time)
    printtime time, '%e %B %Y - %H:%M %Z'
  end

  def shorttime(time)
    printtime time, '%d/%b/%y %H:%M'
  end

  def shortdate(time)
    printtime time, '%d %b %y'
  end

  def longdate(time)
    printtime time, '%e %B %Y'
  end

  def printtime(time, format)
    return unless time

    content_tag(:span, style: 'font-style: italic') do
      Time.use_zone(timezone_offset) { time.strftime(format) }
    end
  end

  # Print the attributes from the list
  def cascade(model, list)
    return '' if model.nil?

    out = list.map do |element|
      name = key = element
      result_parts = []

      if element.instance_of?(Array)
        name = element[0]
        key = element[1]
      end

      if (m = key.to_s.match(/^(.*)_b$/))
        name = m[1]
        key = m[1]
      end

      begin
        # Avoid dynamic eval for security; use public_send or [] accessors
        if model.respond_to?(key)
          str = model.public_send(key)
        elsif model.respond_to?(:[]) && model[key]
          str = model[key]
        else
          next
        end
      rescue StandardError
        next
      end

      next if (str == '') || str.nil?

      result_parts << if model[key].instance_of?(Time) || model[key].instance_of?(ActiveSupport::TimeWithZone)
                        # result << shorttime(str)
                        model[key].to_formatted_s(:long_ordinal)
                      elsif element.instance_of?(Symbol)
                        namelink(str)
                      elsif key.to_s.match(/^(.*)_b$/)
                        sanitize(str.bbcode_to_html.to_s)
                      else
                        h(str)
                      end

      safe_join([
                  content_tag(:dt) do
                    name.to_s.capitalize.gsub(/_s/, '').gsub(/_/, ' ')
                  end,
                  content_tag(:dd) do
                    safe_join(result_parts)
                  end
                ])
    end

    content_tag(:dl) do
      safe_join(out)
    end
  end

  def match_lineup_display(match, lineup, team_class, reverse: false)
    return '' unless lineup.any?

    content_tag(:div, class: team_class) do
      content_tag(:ul) do
        safe_join(lineup.map do |teamer|
          user = teamer.user
          items = []
          if reverse
            items << flag(user.country)
            items << h(user.username)
            items << (user == match.motm ? fa_icon('star') : '')
          else
            items << (user == match.motm ? fa_icon('star') : '')
            items << h(user.username)
            items << flag(user.country)
          end

          content_tag(:li) do
            safe_join(items, ' ')
          end
        end)
      end
    end
  end

  def match_lineups_display(match, team1_lineup, team2_lineup)
    return '' unless team1_lineup.any? || team2_lineup.any?

    classes = ['lineups']
    classes << 'shift' unless team1_lineup.any?

    content_tag(:div, class: classes.join(' ')) do
      content_tag(:div, class: 'lineup-teams') do
        safe_join([
                    match_lineup_display(match, team1_lineup, 'team-1'),
                    match_lineup_display(match, team2_lineup, 'team-2', reverse: true)
                  ])
      end
    end
  end

  def match_list_opponent_team(match, friendly_team = nil)
    home_team = match.contester1&.team
    away_team = match.contester2&.team

    return away_team unless home_team && away_team
    return away_team unless friendly_team

    if friendly_team == home_team
      away_team
    elsif friendly_team == away_team
      home_team
    else
      away_team
    end
  end

  def match_list_score_color(match)
    return 'black' if match.score1.nil? || match.score2.nil?
    return 'yellow' if match.score1 == match.score2

    match.score1 > match.score2 ? 'green' : 'red'
  end

  def match_list_score_text(match)
    "#{match.score1} - #{match.score2}"
  end

  def emojify_aliases(text)
    EmojiParser.parse(text.to_s, &:raw)
  end

  def flag(country)
    if country && country.to_s.size.positive?
      image_tag 'shared/blank.gif', class: "flag flag-#{country.downcase}"
    else
      image_tag 'shared/blank.gif', class: 'flag flag-placeholder'
    end
  end

  def add_comments(object)
    return safe_join([]) unless object.respond_to?(:comments)

    comment = Comment.new(commentable: object)
    comments = object.comments.ordered.with_userteam

    return_here
    render partial: 'comments/index', locals: { comment: comment, comments: comments }
  end

  def link_to_add_fields(name, form_builder, association)
    new_object = form_builder.object.class.reflect_on_association(association).klass.new
    fields = form_builder.fields_for(association, new_object, child_index: "new_#{association}") do |builder|
      render(association.to_s.singularize, f: builder)
    end
    link_to(name, '#', onclick: "add_fields(this, '#{association}', '#{escape_javascript(fields)}'); return false;")
  end

  def timezone_offset
    user = respond_to?(:cuser) ? cuser : nil

    if user
      user.time_zone
    else
      Time.zone.name
    end
  end

  def calendar
    cache = request&.env
    return GoogleCalendar.new(ENV['GOOGLE_CALENDAR_ID'], timezone_offset) unless cache

    cache['application_helper.calendar'] ||= GoogleCalendar.new(ENV['GOOGLE_CALENDAR_ID'], timezone_offset)
  end

  def event_start_time(event)
    event.start.date_time.to_datetime.in_time_zone(timezone_offset)
  end

  def upcoming_matches
    ENV['GOOGLE_CALENDAR'] == 'disabled' ? (calendar.upcoming || []) : []
  end

  def upcoming_nsltv
    ENV['GOOGLE_CALENDAR'] == 'disabled' ? (calendar.upcoming || []) : []
  end
end
