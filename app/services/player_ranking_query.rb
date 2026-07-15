# frozen_string_literal: true

# Pivots the latest batch of AnalysisResult rows -- one row per
# (steamid, model, metric) -- into one ranking hash per player, joined with
# the matching User for display. Used by Analysis::UsersController#index.
#
# "Latest batch" means the highest historical batch_id: each ensl_analysis
# run recomputes skill ratings for the whole player base from all rounds to
# date, so the newest batch is a full snapshot, not a delta.
class PlayerRankingQuery
  # Skill rating models from ensl_analysis; each contributes its 'skill'
  # metric as a `:"skill_#{model}"` column on the returned rows.
  SKILL_MODELS = %w[os dl mlt os_btf os_btp os_tmf].freeze

  # Historical per-player stats, stored under model 'player_stats'.
  PLAYER_STAT_METRICS = %w[wins losses win_ratio].freeze

  def self.call
    new.call
  end

  # Returns an array of hashes: { steamid:, user:, wins:, losses:,
  # win_ratio:, skill_os:, skill_dl:, ... }. Players with no matching User
  # record are skipped since there's nothing sensible to link/display.
  def call
    return [] unless latest_batch_id

    metrics_by_steamid.filter_map do |steamid, metrics|
      user = users_by_steamid[steamid]
      next unless user

      {
        steamid: steamid,
        user: user,
        wins: metrics['player_stats.wins'],
        losses: metrics['player_stats.losses'],
        win_ratio: metrics['player_stats.win_ratio']
      }.merge(skill_columns(metrics))
    end
  end

  private

  def skill_columns(metrics)
    SKILL_MODELS.each_with_object({}) do |model, columns|
      columns[:"skill_#{model}"] = metrics["#{model}.skill"]
    end
  end

  def latest_batch_id
    @latest_batch_id ||= AnalysisResult.historical.maximum(:batch_id)
  end

  def relevant_results
    AnalysisResult.historical
                  .where(batch_id: latest_batch_id)
                  .where.not(steamid: [AnalysisResult::NO_STEAMID, nil])
                  .where(model: SKILL_MODELS + ['player_stats'])
                  .where(metric: %w[skill] + PLAYER_STAT_METRICS)
  end

  def metrics_by_steamid
    @metrics_by_steamid ||= relevant_results.each_with_object(Hash.new { |h, k| h[k] = {} }) do |result, memo|
      memo[result.steamid]["#{result.model.to_s.downcase}.#{result.metric}"] = result.value
    end
  end

  def users_by_steamid
    @users_by_steamid ||= begin
      normalized_by_raw = metrics_by_steamid.keys.each_with_object({}) do |raw_steamid, memo|
        normalized = User.normalize_steamid(raw_steamid)
        memo[raw_steamid] = normalized if normalized
      end

      users_by_normalized = User.where(steamid: normalized_by_raw.values.uniq).index_by(&:steamid)
      normalized_by_raw.each_with_object({}) do |(raw_steamid, normalized_steamid), memo|
        user = users_by_normalized[normalized_steamid]
        memo[raw_steamid] = user if user
      end
    end
  end
end
