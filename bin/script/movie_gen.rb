#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../../config/environment'

scope = Movie.includes(:file, :preview).order(:id)
total = scope.count
started_at = Time.now
tick = (ENV['PROGRESS_EVERY'] || 25).to_i
tick = 25 if tick <= 0

stats = Hash.new(0)

puts "Movies: #{total}"

scope.find_each.with_index(1) do |movie, i|
  source = movie.processable_source_path

  unless source
    stats[:skipped_missing_file] += 1
    if (i % tick).zero? || i == total
      puts "[#{i}/#{total}] snap=#{stats[:snapshots]} prev=#{stats[:previews]} skip=#{stats[:skipped_missing_file]} fail=#{stats[:failed]}"
    end
    next
  end

  begin
    movie.probe_metadata
    movie.probe_length
    movie.update_columns(
      metadata: movie.metadata,
      web_friendly: movie.web_friendly,
      format: movie.format,
      length: movie.length,
      updated_at: Time.current
    )
    stats[:probed] += 1
  rescue StandardError
    stats[:failed] += 1
  end

  unless movie.snapshot?
    if movie.make_snapshot
      stats[:snapshots] += 1
    else
      stats[:failed] += 1
    end
  end

  needs_preview = !movie.web_friendly && !movie.preview_exists?
  if needs_preview
    begin
      movie.make_preview
      stats[:previews] += 1
    rescue StandardError
      stats[:failed] += 1
    end
  end

  if (i % tick).zero? || i == total
    puts "[#{i}/#{total}] probe=#{stats[:probed]} snap=#{stats[:snapshots]} prev=#{stats[:previews]} skip=#{stats[:skipped_missing_file]} fail=#{stats[:failed]}"
  end
end

elapsed = (Time.now - started_at).round
puts "Done in #{elapsed}s | probed=#{stats[:probed]} snapshots=#{stats[:snapshots]} previews=#{stats[:previews]} skipped_missing_file=#{stats[:skipped_missing_file]} failed=#{stats[:failed]}"
