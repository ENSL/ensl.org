# frozen_string_literal: true

File.join(File.dirname(__FILE__), '/../lib/')

module RailsLog
  class Processor
    def self.process(input)
      waiting_for_time = false

      summary = Hash.new { |h, k| h[k] = [] }
      info = {}
      while (line = input.gets)
        if waiting_for_time
          if line[0..11] == 'Completed in'
            completed_view_regex = /
              ^Completed\s*in\s*([^\s]+)
              \s*\(View:\s*(\d+),\s*DB:\s*(\d+)\)
              \s*\|\s*(\d+)\s*\w+\s*\[([^\]]+)\]
            /ix
            completed_render_regex = /
              Completed\s*in\s*([^\s]+)
              \s*\([^)]+\)\s*\|\s*Rendering:\s*([\d.]+)
              \s*\([^)]+\)\s*\|\s*DB:\s*([\d.]+)
              \s*\([^)]+\)\s*\|\s*(\d+)\s*\w+\s*\[([^\]]+)\]
            /ix

            if line =~ completed_view_regex
              info.merge!(
                processing_time: ::Regexp.last_match(1),
                view_time: ::Regexp.last_match(2),
                db_time: ::Regexp.last_match(3),
                status: ::Regexp.last_match(4),
                url: ::Regexp.last_match(5)
              )
              summary["#{info[:controller]}##{info[:action]}"] << info[:processing_time].to_i
            elsif line =~ completed_render_regex
              info.merge!(
                processing_time: (::Regexp.last_match(1).to_f * 100).to_i,
                view_time: (::Regexp.last_match(2).to_f * 100).to_i,
                db_time: (::Regexp.last_match(3).to_f * 100).to_i,
                status: ::Regexp.last_match(4),
                url: ::Regexp.last_match(5)
              )
              summary["#{info[:controller]}##{info[:action]}"] << info[:processing_time].to_i
            end
            waiting_for_time = false
          end
        elsif (line[0..9] == 'Processing') &&
              (line =~ /^Processing\s*([^#]+)#([^\s]+)\s*\(for\s*([^\s]+)\s*at\s*([^)]+)\)\s*\[(\w+)\]/i)
          info = {
            controller: ::Regexp.last_match(1),
            action: ::Regexp.last_match(2),
            ip: ::Regexp.last_match(3),
            datetime: ::Regexp.last_match(4),
            method: ::Regexp.last_match(4)
          }
          waiting_for_time = true
        end
      end

      stats = []
      summary.each_key do |k|
        values = summary[k]
        sum, max, min, avg, median = 0
        if values.length.positive?
          values.sort!
          sum = values.inject(0) { |sum, i| sum + i }
          max = values[-1]
          min = values[0]
          avg = sum / values.length
          median = values.length.even? ? (values[1 / 2 - 1] + values[1 / 2]) / 2 : values[(values.length + 1) / 2 - 1]
        end
        stats << Stats.new(k, values.size, sum, max, min, avg, median)
      end
      stats
    end
  end

  class Stats
    attr_accessor :uri, :count, :sum, :max, :min, :avg, :median

    def initialize(uri, count, sum, max, min, avg, median)
      @uri = uri
      @count = count
      @sum = sum
      @max = max
      @min = min
      @avg = avg
      @median = median
    end
  end

  def self.run
    sort_by_key = nil
    result_limit = 0
    ARGV.each_with_index do |arg, i|
      if ['--sort', '-s'].include?(arg)
        sort_by_key = ARGV[i + 1]
      elsif ['--limit', '-l'].include?(arg)
        result_limit = ARGV[i + 1].to_i
      elsif ['--help', '-h'].include?(arg)
        print_usage
        exit
      end
    end

    file = ARGV.size.positive? ? ARGV[-1] : nil
    stats = nil
    if !file.nil? && File.exist?(file)
      File.open(file, 'r') do |f|
        stats = Processor.process f
      end
    else
      stats = Processor.process $stdin
    end

    stats_array = []
    sort_by_key = 'median' unless !sort_by_key.nil? && stats[0].respond_to?(sort_by_key)
    stats.sort_by { |s| s.send(sort_by_key) }.reverse.each do |s|
      stats_array << [s.uri, s.count, s.sum, s.max, s.min, s.avg, s.median]
    end
    stats_array = stats_array[0..result_limit - 1] if result_limit.positive?
    stats_array.tabalize(
      ['Uri', 'Calls', 'Total Time', 'Max', 'Min', 'Avg', 'Median'],
      %i[left right right right right right right]
    )
  end

  def self.print_usage
    puts <<~USAGE
      ruby #{File.basename(__FILE__)} [options] [FILE]

      Parses a rails log file and prints out call time information by controller#action pair.
      With no FILE, or when FILE is -, read standard input.

      options:
        --help | -h            Print this help screen
        --sort | -s <key>      Sort the results by key
                               valid keys are:
                                  count  - The total number of calls
                                  sum    - The total call time
                                  max    - The maximum call time
                                  min    - The minimum call time
                                  avg    - The average call time
                                  median - The median call time (default)
        --limit | -l <limit>   Limit the number of results displayed

      examples:

        ruby #{File.basename(__FILE__)} --sort count < $RAILS_ROOT/logs/development.log

        gunzip -c $RAILS_ROOT/logs/development.log.gz | ruby #{File.basename(__FILE__)} --sort count --limit 20 -

    USAGE
    exit
  end
end

class Array
  def tabalize(headings, justifications = nil, out = $stdout)
    raise ArgumentError, 'only works on an array of arrays' if size.positive? && ![0].is_a?(Array)
    if size.positive? && (headings.size != [0].size) && !justifications.nil? && (headings.size != justifications.size)
      raise ArgumentError, 'headings, justifications and array elements must all have the same number of elements'
    end

    sizes = Array.new(headings.size, 0)
    headings.each_with_index do |h, i|
      sizes[i] = [sizes[i], h.to_s.length].max
    end
    each do |row|
      row.each_with_index do |e, i|
        sizes[i] = [sizes[i], e.to_s.length].max
      end
    end

    print_tablalize_lines(out, sizes)

    out.write '| '
    sizes.each_with_index do |s, i|
      out.write ' | ' if i.positive?
      out.write headings[i].ljust(s, ' ')
    end
    out.write " |\n"

    print_tablalize_lines(out, sizes)

    each do |row|
      out.write '| '
      sizes.each_with_index do |s, i|
        out.write ' | ' if i.positive?
        out.write row[i].to_s.send("#{justifications[i].to_s[0..0]}just", s, ' ')
      end
      out.write " |\n"
    end

    print_tablalize_lines(out, sizes)
  end

  private

  def print_tablalize_lines(out, sizes)
    out.write '+-'
    sizes.each_with_index do |s, i|
      out.write '-+-' if i.positive?
      out.write ''.ljust(s, '-')
    end
    out.write "-+\n"
  end
end

RailsLog.run
