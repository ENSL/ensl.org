# frozen_string_literal: true

# Aggregates ENSL account countries with imported NS1 round participation and
# the latest DL skill snapshot for the country analysis page.
class CountryStatisticsQuery
  MIN_ACCOUNT_COUNTRY_PLAYERS = 11
  MIN_ROUND_COUNTRY_PLAYERS = 5
  OTHER_COUNTRY = 'Other countries'
  TOP_SKILL_COUNT = 10
  DL_SKILL_MULTIPLIER = 10_000
  DL_SKILL_OFFSET = 1_000

  def self.call
    new.call
  end

  def call
    {
      all_players: all_player_rows,
      round_skill_players: round_skill_rows,
      skill_per_player_players: skill_per_player_rows
    }
  end

  private

  def all_player_rows
    counts_by_country = User.group(:country).count.each_with_object(Hash.new(0)) do |(country, count), counts|
      counts[country.to_s.strip] += count
    end
    prominent_countries, other_countries = counts_by_country.partition do |country, count|
      country.present? && count >= MIN_ACCOUNT_COUNTRY_PLAYERS
    end
    prominent_countries = prominent_countries.to_h
    prominent_countries[OTHER_COUNTRY] = other_countries.sum { |_country, count| count } if other_countries.any?

    build_country_rows(prominent_countries) { |country, count| { country: country, players: count } }
  end

  def round_skill_rows
    filtered_round_skill_rows.sort_by { |row| [-row[:average_skill], row[:country_name]] }
  end

  def skill_per_player_rows
    filtered_round_skill_rows.sort_by { |row| [-row[:skill_per_player], row[:country_name]] }
  end

  def filtered_round_skill_rows
    @filtered_round_skill_rows ||= round_player_rows.select do |row|
      row[:players] >= MIN_ROUND_COUNTRY_PLAYERS && row[:average_skill]
    end
  end

  def round_player_rows
    players_by_country = participating_users.group_by { |user| user[:country] }
    skills_by_steamid = latest_dl_skills

    players_by_country.map do |country, players|
      skills = players.filter_map do |player|
        raw_skill = skills_by_steamid[User.normalize_steamid(player[:steamid])]
        display_dl_skill(raw_skill) if raw_skill
      end
      average_skill = skills.empty? ? nil : skills.sum.fdiv(skills.size)
      top_skills = skills.max(TOP_SKILL_COUNT)

      {
        country: country,
        country_code: country,
        country_name: country_name(country),
        players: players.size,
        average_skill: average_skill,
        top_ten_average_skill: top_skills.empty? ? nil : top_skills.sum.fdiv(top_skills.size),
        skill_per_player: average_skill&.fdiv(players.size)
      }
    end
  end

  # A player may have many Rounder records, but must contribute once to their
  # country total. Rounder steamids include the STEAM_ prefix used by imports.
  def participating_users
    User.joins("INNER JOIN rounders ON users.steamid = REPLACE(rounders.steamid, 'STEAM_', '')")
        .where.not(country: [nil, '', '--'])
        .distinct
        .pluck(:id, :steamid, :country)
        .map { |id, steamid, country| { id: id, steamid: steamid, country: country } }
  end

  def latest_dl_skills
    latest_batch_id = AnalysisResult.historical.maximum(:batch_id)
    return {} unless latest_batch_id

    steamids_by_user_id = AnalysisResult.user_steamids(latest_batch_id)
    scope = AnalysisResult.historical.where(batch_id: latest_batch_id, model: 'dl')
                          .where(field: %w[user_id skill_dl])
    AnalysisResult.rows_from(scope).each_with_object({}) do |row, skills|
      steamid = User.normalize_steamid(steamids_by_user_id[row['user_id'].to_i])
      skills[steamid] = row['skill_dl'] if steamid && row['skill_dl']
    end
  end

  def build_country_rows(counts_by_country)
    rows = counts_by_country.map do |country, count|
      yield(country, count).merge(country_code: country, country_name: country_name(country))
    end
    sort_rows(rows)
  end

  def country_name(country)
    country_object = ISO3166::Country[country]
    country_object&.translations&.[](I18n.locale.to_s) || country_object&.translations&.[]('en') || country
  end

  def display_dl_skill(raw_skill)
    (raw_skill * DL_SKILL_MULTIPLIER) + DL_SKILL_OFFSET
  end

  def sort_rows(rows)
    rows.sort_by { |row| [-row[:players], row[:country_name].to_s] }
  end
end
