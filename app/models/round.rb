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
  LENGTH_BUCKETS = {
    'under_5' => [0, 5 * 60],
    '5_to_10' => [5 * 60, 10 * 60],
    '10_to_20' => [10 * 60, 20 * 60],
    '20_to_30' => [20 * 60, 30 * 60],
    'over_30' => [30 * 60, nil]
  }.freeze

  # Matches a player token embedded in LogLine#raw_text, e.g.
  # `"jiriki<15><STEAM_0:1:1511705><marine1team>"` -- used by observed_teams
  # below to read a player's actual in-round team straight from the log,
  # independent of the imported Rounder#team (see RounderTeamValidator).
  OBSERVED_TEAM_RE = /"(?:.+?)<\d+><(STEAM_[\d:]+)><([^">]*)>"/

  has_many :rounders, dependent: :destroy
  has_many :log_lines, dependent: :destroy

  scope :chronologically, -> { order(start_time: :asc, id: :asc) }
  scope :with_players_and_users, lambda {
    left_joins(:rounders).joins("LEFT JOIN users ON users.steamid = REPLACE(rounders.steamid, 'STEAM_', '')")
  }
  scope :with_log_lines, -> { joins('LEFT JOIN log_lines ON log_lines.round_id = rounds.id') }
  scope :for_steamid, ->(steamid) { steamid.present? ? where('rounders.steamid LIKE ?', "%#{steamid}%") : self }
  scope :for_username, ->(username) { username.present? ? where('users.username LIKE ?', "%#{username}%") : self }
  scope :for_nickname, lambda { |nickname|
    nickname.present? ? where('log_lines.raw_text LIKE ?', "%\"#{nickname}%<%") : self
  }
  scope :for_map, ->(map_name) { map_name.present? ? where('rounds.map_name LIKE ?', "%#{map_name}%") : self }
  scope :for_server, lambda { |server_name|
    server_name.present? ? where('rounds.server_name LIKE ?', "%#{server_name}%") : self
  }
  scope :for_result, ->(result) { %w[0 1].include?(result.to_s) ? where(result: result) : self }
  scope :for_length, ->(bucket) { Round.apply_length_filter(self, bucket) }
  scope :between_dates, ->(from, to) { Round.apply_date_filter(self, from, to) }

  ARCHIVE_FILTER_SCOPES = {
    steamid: :for_steamid,
    username: :for_username,
    nickname: :for_nickname,
    map: :for_map,
    server: :for_server,
    result: :for_result,
    length: :for_length
  }.freeze

  def self.present_map_names
    where.not(map_name: [nil, '']).distinct.order(:map_name).pluck(:map_name)
  end

  def self.present_server_names
    where.not(server_name: [nil, '']).distinct.order(:server_name).pluck(:server_name)
  end

  def self.counts_by_day_in(year)
    where(start_time: Date.new(year, 1, 1)...Date.new(year + 1, 1, 1)).group('DATE(start_time)').count
  end

  def self.filtered(filters)
    ARCHIVE_FILTER_SCOPES.reduce(all) do |scope, (filter, scope_name)|
      scope.public_send(scope_name, filters[filter])
    end.between_dates(filters[:from], filters[:to]).distinct
  end

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

  def previous
    self.class.where('start_time < ? OR (start_time = ? AND id < ?)', start_time, start_time, id)
        .order(start_time: :desc, id: :desc).first
  end

  def next
    self.class.where('start_time > ? OR (start_time = ? AND id > ?)', start_time, start_time, id)
        .chronologically.first
  end

  def timeline_log_lines
    timeline = log_lines.where.not(event_type: %w[attacked player_acts])
    timeline = timeline.where(created_at: start_time..) if start_time
    timeline.order(:created_at, :id)
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

  def self.apply_length_filter(scope, bucket)
    minimum, maximum = LENGTH_BUCKETS.fetch(bucket.to_s, [nil, nil])
    return scope unless minimum

    scope = scope.where('rounds.end_time IS NOT NULL')
    scope = scope.where('TIMESTAMPDIFF(SECOND, rounds.start_time, rounds.end_time) >= ?', minimum)
    return scope unless maximum

    scope.where('TIMESTAMPDIFF(SECOND, rounds.start_time, rounds.end_time) < ?', maximum)
  end

  def self.apply_date_filter(scope, from, to)
    from_time = Time.zone.parse(from.to_s)
    to_time = Time.zone.parse(to.to_s)
    scope = scope.where('rounds.start_time >= ?', from_time) if from_time
    scope = scope.where('rounds.start_time < ?', to_time + 1.day) if to_time
    scope
  rescue ArgumentError
    scope
  end

  private

  def observed_team_side(suffix)
    return 'marine' if suffix.start_with?('marine')
    return 'alien' if suffix.start_with?('alien')

    nil
  end
end
