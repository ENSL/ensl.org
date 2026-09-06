# frozen_string_literal: true

# == Schema Information
#
# Table name: rounds
#
#  id          :integer          not null, primary key
#  server_name :string(255)
#  start_time  :datetime
#  end_time    :datetime
#  map_name    :string(255)
#  result      :integer
#
# Indexes
#
#  index_rounds_on_server_name_and_start_time (server_name, start_time) UNIQUE
#

# One NS1 round, imported from the ensl_analysis Python pipeline's `rounds`
# parquet export (see RoundBatchImportService). Not tied to any ladder
# match/team/map record -- the pipeline only knows about servers and maps by
# name, not our Server/Map/Match/Team rows.
#
# `id` here is a Rails-assigned primary key, not the Python exporter's own
# `rounds.id` -- that id is just a per-run counter, not stable across
# batches, so rows are upserted on (server_name, start_time) instead (see
# the RestructureRoundAndLogModels migration for why).
class Round < ApplicationRecord
  RESULT_MARINE_WIN = 1
  RESULT_ALIEN_WIN = 0

  # Matches a player token embedded in LogLine#raw_text, e.g.
  # `"jiriki<15><STEAM_0:1:1511705><marine1team>"` -- used by observed_teams
  # below to read a player's actual in-round team straight from the log,
  # independent of the imported Rounder#team (see RounderTeamValidator).
  OBSERVED_TEAM_RE = /"(?:.+?)<\d+><(STEAM_[\d:]+)><([^">]*)>"/

  has_many :rounders, dependent: :destroy
  has_many :log_lines, dependent: :destroy

  def winner_s
    case result
    when RESULT_MARINE_WIN then 'Marines'
    when RESULT_ALIEN_WIN then 'Aliens'
    end
  end

  def length
    return nil unless start_time && end_time

    total_seconds = (end_time - start_time).to_i
    format('%<minutes>02d:%<seconds>02d', minutes: total_seconds / 60, seconds: total_seconds % 60)
  end

  # steamid -> tally of {'marine' => N, 'alien' => M} seen in this round's own
  # log lines -- the imported `round_users`/Rounder#team can be wrong (see
  # /memories/repo/round-timeline.md for confirmed real examples), so this is
  # the ground truth RounderTeamValidator checks it against. Memoized per
  # Round instance -- reuse the same instance across all its rounders (e.g.
  # `round.rounders.each { |r| r.valid?(:team_check) }`) to scan the log
  # lines once per round rather than once per rounder.
  def observed_teams
    @observed_teams ||= begin
      tally = Hash.new { |hash, steamid| hash[steamid] = Hash.new(0) }
      log_lines.find_each do |log_line|
        log_line.raw_text.to_s.scan(OBSERVED_TEAM_RE) do |steamid, suffix|
          side = observed_team_side(suffix)
          tally[steamid][side] += 1 if side
        end
      end
      tally
    end
  end

  private

  def observed_team_side(suffix)
    return 'marine' if suffix.start_with?('marine')
    return 'alien' if suffix.start_with?('alien')

    nil
  end
end
