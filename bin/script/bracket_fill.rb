#!/usr/bin/env ruby
# frozen_string_literal: true

# Loads a complete bracket contest with randomized data for dev env.
# Creates contest, brackets, teams, and matches with realistic bracket structures.
# Uses factories to generate realistic, varied bracket data.
# Usage: bundle exec bin/script/contest_fill.rb

require_relative '../../config/environment'

include FactoryBot::Syntax::Methods

# Run the script
begin
  ActiveRecord::Base.transaction do
    # Create a complete randomized bracket contest with all related data
    contest = create(:contest, :randomized_bracket_contest,
                     name: "Random Bracket Contest #{Time.now.to_i}")

    # Print summary
    puts "\n#{'=' * 60}"
    puts 'CONTEST SETUP COMPLETE'
    puts('=' * 60)
    puts "Contest: #{contest.name} (ID: #{contest.id})"
    puts "Brackets: #{contest.brackets.count}"

    contest.brackets.each do |bracket|
      team_count = bracket.bracketers.where.not(team_id: nil).distinct.count(:team_id)
      match_count = bracket.bracketers.where.not(match_id: nil).distinct.count(:match_id)
      total_bracketers = bracket.bracketers.count
      puts "  - #{bracket.name}: #{team_count} teams, #{match_count} matches, #{total_bracketers} bracketers"
    end

    puts "Teams: #{contest.contesters.count}"
    puts "Matches: #{contest.matches.count}"
    puts "Maps: #{contest.maps.count}"
    puts('=' * 60)
    puts "\nYou can now view the contest at: /contests/#{contest.id}"
  end
rescue StandardError => e
  puts "Error: #{e.message}"
  puts e.backtrace.join("\n")
  exit 1
end
