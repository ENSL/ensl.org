# frozen_string_literal: true

# Pivots the newest historical class-stat cells into one row per (player,
# class). Derived rates exist only for the class-performance page.
class ClassPerformanceQuery
  METRICS = %w[kills deaths damage minutes_played resources_spent wins losses sample_size].freeze
  EXCLUDED_CLASSES = %w[heavy jetpack].freeze
  MIN_GAMES_OPTIONS = PlayerRankingQuery::MIN_GAMES_OPTIONS
  DEFAULT_MIN_GAMES = PlayerRankingQuery::DEFAULT_MIN_GAMES

  def self.call(class_name: nil, min_games: nil)
    new(class_name: class_name, min_games: min_games).call
  end

  def self.class_names
    latest_batch_id = AnalysisResult.historical.maximum(:batch_id)
    return [] unless latest_batch_id

    AnalysisResult.rows_from(
      AnalysisResult.historical.where(batch_id: latest_batch_id, model: 'class_stats').where(field: 'class_name')
    ).filter_map { |row| row['class_name'] }
     .reject { |class_name| EXCLUDED_CLASSES.include?(class_name) }.uniq.sort
  end

  def initialize(class_name: nil, min_games: nil)
    @class_name = class_name.presence
    @min_games = normalize_min_games(min_games)
  end

  def call
    return [] unless latest_batch_id

    grouped_metrics.filter_map do |steamid, metrics|
      user = users_by_steamid[steamid]
      next unless user
      next if @min_games && metrics['sample_size'].present? && metrics['sample_size'] < @min_games

      performance(user, metrics)
    end
  end

  def possible_users
    grouped_metrics.keys.intersection(users_by_steamid.keys).size
  end

  def rounds_analysed
    Round.where.not(result: nil).count
  end

  private

  def latest_batch_id
    @latest_batch_id ||= AnalysisResult.historical.maximum(:batch_id)
  end

  def metrics_by_subject
    initial_metrics = Hash.new { |hash, key| hash[key] = Hash.new(0) }
    @metrics_by_subject ||= class_stat_rows.each_with_object(initial_metrics) do |row, memo|
      steamid = steamids_by_user_id[row['user_id'].to_i]
      class_name = row['class_name'].presence
      next unless steamid && class_name

      METRICS.each { |field| memo[[steamid, class_name]][field] += row[field].to_f if row[field] }
    end
  end

  def class_stat_rows
    @class_stat_rows ||= AnalysisResult.rows_from(
      AnalysisResult.historical.where(batch_id: latest_batch_id, model: 'class_stats')
                    .where(field: %w[user_id class_name] + METRICS)
    )
  end

  def steamids_by_user_id
    @steamids_by_user_id ||= AnalysisResult.user_steamids(latest_batch_id)
  end

  def users_by_steamid
    @users_by_steamid ||= begin
      normalized_by_raw = metrics_by_subject.keys.map(&:first).uniq.each_with_object({}) do |raw_steamid, memo|
        normalized = User.normalize_steamid(raw_steamid)
        memo[raw_steamid] = normalized if normalized
      end

      users_by_normalized = User.where(steamid: normalized_by_raw.values.uniq).index_by(&:steamid)
      normalized_by_raw.transform_values { |normalized| users_by_normalized[normalized] }.compact
    end
  end

  def grouped_metrics
    selected_metrics = metrics_by_subject.select do |(_steamid, class_name), _metrics|
      @class_name.nil? || class_name == @class_name
    end
    return selected_metrics.transform_keys(&:first) if @class_name

    empty_metrics = Hash.new { |hash, key| hash[key] = Hash.new(0) }
    selected_metrics.each_with_object(empty_metrics) do |((steamid, class_name), metrics), totals|
      next if EXCLUDED_CLASSES.include?(class_name)

      metrics.each { |metric, value| totals[steamid][metric] += value.to_f }
    end
  end

  def rate(numerator, denominator)
    return nil unless numerator && denominator&.positive?

    numerator / denominator
  end

  def normalize_min_games(value)
    return nil if value.nil?

    numeric = Integer(value, exception: false)
    return DEFAULT_MIN_GAMES unless MIN_GAMES_OPTIONS.include?(numeric)

    numeric
  end

  def performance(user, metrics)
    damage = metrics['damage']
    minutes_played = metrics['minutes_played']
    resources_spent = metrics['resources_spent']

    {
      user: user, class_name: @class_name,
      kills: metrics['kills'], deaths: metrics['deaths'], damage: damage,
      kill_death_ratio: rate(metrics['kills'], metrics['deaths']),
      minutes_played: minutes_played, damage_per_minute: rate(damage, minutes_played),
      resources_spent: resources_spent, damage_per_resource: rate(damage, resources_spent),
      resources_per_minute: rate(resources_spent, minutes_played), wins: metrics['wins'],
      losses: metrics['losses'], sample_size: metrics['sample_size'],
      win_rate: rate(metrics['wins'], metrics['sample_size'])
    }
  end
end
