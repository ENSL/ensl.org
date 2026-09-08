# frozen_string_literal: true

# Pivots the newest historical class-stat result batch into one row per
# (player, class). Class source rows were aggregated across maps and teams at
# import time; derived rates here exist only for the class-performance page.
class ClassPerformanceQuery
  METRICS = %w[kills deaths damage minutes_played resources_spent wins losses sample_size].freeze
  MODEL_PREFIX = 'class_stats:'
  MIN_GAMES_OPTIONS = [25, 50, 100].freeze
  DEFAULT_MIN_GAMES = MIN_GAMES_OPTIONS.first

  def self.call(class_name: nil, min_games: nil)
    new(class_name: class_name, min_games: min_games).call
  end

  def self.class_names
    latest_batch_id = AnalysisResult.historical.maximum(:batch_id)
    return [] unless latest_batch_id

    AnalysisResult.historical
                  .where(batch_id: latest_batch_id)
                  .where('model LIKE ?', "#{MODEL_PREFIX}%")
                  .distinct
                  .pluck(:model)
                  .map { |model| model.delete_prefix(MODEL_PREFIX) }
                  .sort
  end

  def initialize(class_name: nil, min_games: nil)
    @class_name = class_name.presence
    @min_games = normalize_min_games(min_games)
  end

  def call
    return [] unless latest_batch_id

    metrics_by_subject.filter_map do |(steamid, model), metrics|
      user = users_by_steamid[steamid]
      next unless user
      next if @class_name && model != "#{MODEL_PREFIX}#{@class_name}"
      next if @min_games && metrics['sample_size'].present? && metrics['sample_size'] < @min_games

      performance(user, model, metrics)
    end
  end

  private

  def latest_batch_id
    @latest_batch_id ||= AnalysisResult.historical.maximum(:batch_id)
  end

  def relevant_results
    AnalysisResult.historical
                  .where(batch_id: latest_batch_id)
                  .where.not(steamid: [AnalysisResult::NO_STEAMID, nil])
                  .where('model LIKE ?', "#{MODEL_PREFIX}%")
                  .where(metric: METRICS)
  end

  def metrics_by_subject
    @metrics_by_subject ||= relevant_results.each_with_object(Hash.new { |hash, key| hash[key] = {} }) do |result, memo|
      memo[[result.steamid, result.model]][result.metric] = result.value
    end
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

  def performance(user, model, metrics)
    damage = metrics['damage']
    minutes_played = metrics['minutes_played']
    resources_spent = metrics['resources_spent']

    {
      user: user, class_name: model.delete_prefix(MODEL_PREFIX),
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
