#!/usr/bin/env ruby
# frozen_string_literal: true

# Cross-checks every Rounder#team against what that round's own log lines
# actually show (see RounderTeamValidator, Round#observed_teams) and reports
# any mismatches. This is a read-only diagnostic for the ensl_analysis Python
# round_users exporter, which is the actual source of these values (see
# /memories/repo/round-timeline.md for confirmed real examples/root cause
# notes) -- it never modifies any data.
#
# Usage:
#   bundle exec script/validate_rounds.rb            # scan every round
#   bundle exec script/validate_rounds.rb 542 1130    # scan specific round ids

require_relative '../config/environment'

round_ids = ARGV.map(&:to_i).select(&:positive?)
scope = round_ids.any? ? Round.where(id: round_ids) : Round.all

rounds_scanned = 0
mismatches = 0

scope.find_each do |round|
  rounds_scanned += 1

  round.rounders.each do |rounder|
    next if rounder.valid?(:team_check)

    mismatches += 1
    puts "Round #{round.id} (#{round.server_name}, #{round.start_time}): " \
         "#{rounder.steamid} #{rounder.errors[:team].join('; ')}"
  end
end

puts "\n#{mismatches} mismatch(es) found across #{rounds_scanned} round(s) scanned."
