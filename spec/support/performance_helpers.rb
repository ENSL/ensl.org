# frozen_string_literal: true

module PerformanceHelpers
  module QueryCounter
    IGNORED_QUERY_NAMES = %w[SCHEMA CACHE TRANSACTION].freeze

    def count_sql_queries(&block)
      count = 0

      callback = lambda do |_name, _start, _finish, _id, payload|
        sql = payload[:sql].to_s
        name = payload[:name].to_s

        next if IGNORED_QUERY_NAMES.include?(name)
        next if sql.start_with?('SAVEPOINT', 'RELEASE SAVEPOINT', 'ROLLBACK TO SAVEPOINT')

        count += 1
      end

      ActiveSupport::Notifications.subscribed(callback, 'sql.active_record', &block)
      count
    end
  end

  module FrontPageSeed
    PROFILE_TARGETS = {
      'small' => {
        articles: 750,
        comments: 6_000,
        topics: 200,
        posts: 2_500,
        shoutmsgs: 1_500,
        gathers: 120,
        gatherers: 3_000,
        teams: 1_000,
        contesters: 2_000,
        matches: 1_800,
        issues: 2_500,
        messages: 4_000,
        votes: 6_000
      },
      'medium' => {
        articles: 5_000,
        comments: 45_000,
        topics: 2_000,
        posts: 35_000,
        shoutmsgs: 12_000,
        gathers: 700,
        gatherers: 22_000,
        teams: 8_000,
        contesters: 18_000,
        matches: 12_000,
        issues: 16_000,
        messages: 22_000,
        votes: 40_000
      },
      'large' => {
        articles: 20_000,
        comments: 180_000,
        topics: 8_000,
        posts: 140_000,
        shoutmsgs: 45_000,
        gathers: 2_500,
        gatherers: 90_000,
        teams: 30_000,
        contesters: 70_000,
        matches: 50_000,
        issues: 60_000,
        messages: 90_000,
        votes: 120_000
      }
    }.freeze

    RELEVANT_TABLES = %w[
      articles comments users polls options topics posts forums forumers
      gathers gatherers shoutmsgs teams contesters matches issues messages
      votes read_marks profiles bans groups groupers
    ].freeze

    def seed_front_page_performance_data!
      profile = ENV.fetch('PERF_FRONT_PAGE_PROFILE', 'medium')
      targets = seed_targets(profile)
      dataset = create(:front_page_dataset, targets: targets, now: Time.current)

      {
        profile: profile,
        source_counts: source_table_counts
      }.merge(dataset.to_h)
    end

    private

    def seed_targets(profile)
      baseline = PROFILE_TARGETS.fetch(profile, PROFILE_TARGETS['medium']).dup
      counts = source_table_counts
      return baseline if counts.empty?

      scale = ENV.fetch('PERF_SOURCE_SCALE', '0.05').to_f
      baseline.each_key do |key|
        source_value = counts.fetch(key.to_s, 0).to_i
        next unless source_value.positive?

        baseline[key] = [[(source_value * scale).to_i, PROFILE_TARGETS['small'][key]].max,
                         PROFILE_TARGETS['large'][key]].min
      end

      baseline
    end

    def source_table_counts
      source_db = ENV['PERF_SOURCE_DATABASE'].to_s.strip
      return {} if source_db.empty?

      quoted_db = ActiveRecord::Base.connection.quote(source_db)
      quoted_tables = RELEVANT_TABLES.map { |table| ActiveRecord::Base.connection.quote(table) }.join(', ')

      sql = <<~SQL
        SELECT table_name, table_rows
        FROM information_schema.tables
        WHERE table_schema = #{quoted_db}
          AND table_name IN (#{quoted_tables})
      SQL

      rows = ActiveRecord::Base.connection.select_rows(sql)
      rows.to_h { |name, count| [name, count.to_i] }
    rescue StandardError
      {}
    end
  end
end

RSpec.configure do |config|
  config.include PerformanceHelpers::QueryCounter
  config.include PerformanceHelpers::FrontPageSeed, performance: true
end
