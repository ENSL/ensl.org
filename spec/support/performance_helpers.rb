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
      'small' => { articles: 750, comments: 6_000 },
      'medium' => { articles: 5_000, comments: 45_000 },
      'large' => { articles: 20_000, comments: 180_000 }
    }.freeze

    RELEVANT_TABLES = %w[articles comments users polls options].freeze

    def seed_front_page_performance_data!
      profile = ENV.fetch('PERF_FRONT_PAGE_PROFILE', 'medium')
      targets = seed_targets(profile)

      now = Time.current
      news_category = Category.create!(name: 'Performance News', domain: Category::DOMAIN_NEWS, sort: 0)
      author = create(:user)

      article_rows = build_article_rows(
        category_id: news_category.id,
        user_id: author.id,
        count: targets[:articles],
        now: now
      )
      Article.insert_all!(article_rows) if article_rows.any?

      article_ids = Article.where(category_id: news_category.id).order(id: :desc).limit(targets[:articles]).pluck(:id)
      comment_rows = build_comment_rows(article_ids: article_ids, count: targets[:comments], user_id: author.id,
                                        now: now)
      Comment.insert_all!(comment_rows) if comment_rows.any?

      poll = Poll.new(question: 'Performance polling question?', user_id: author.id)
      poll.options.build(option: 'Yes')
      poll.options.build(option: 'No')
      poll.save!

      {
        profile: profile,
        articles_seeded: targets[:articles],
        comments_seeded: targets[:comments],
        source_counts: source_table_counts
      }
    end

    private

    def seed_targets(profile)
      baseline = PROFILE_TARGETS.fetch(profile, PROFILE_TARGETS['medium']).dup
      source_counts = source_table_counts
      return baseline if source_counts.empty?

      scale = ENV.fetch('PERF_SOURCE_SCALE', '0.05').to_f
      source_articles = source_counts.fetch('articles', 0).to_i
      source_comments = source_counts.fetch('comments', 0).to_i

      if source_articles.positive?
        baseline[:articles] = [[(source_articles * scale).to_i, PROFILE_TARGETS['small'][:articles]].max,
                               PROFILE_TARGETS['large'][:articles]].min
      end

      if source_comments.positive?
        baseline[:comments] = [[(source_comments * scale).to_i, PROFILE_TARGETS['small'][:comments]].max,
                               PROFILE_TARGETS['large'][:comments]].min
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

    def build_article_rows(category_id:, user_id:, count:, now:)
      (0...count).map do |index|
        created_at = now - index.minutes
        {
          category_id: category_id,
          user_id: user_id,
          title: "Performance Article #{index}",
          text: "Generated performance article body #{index}",
          text_parsed: "Generated performance article body #{index}",
          text_coding: Article::CODING_BBCODE,
          status: Article::STATUS_PUBLISHED,
          created_at: created_at,
          updated_at: created_at
        }
      end
    end

    def build_comment_rows(article_ids:, count:, user_id:, now:)
      return [] if article_ids.empty? || count.zero?

      article_count = article_ids.length
      (0...count).map do |index|
        {
          commentable_type: 'Article',
          commentable_id: article_ids[index % article_count],
          user_id: user_id,
          text: "Generated performance comment #{index}",
          text_parsed: "Generated performance comment #{index}",
          created_at: now,
          updated_at: now
        }
      end
    end
  end
end

RSpec.configure do |config|
  config.include PerformanceHelpers::QueryCounter
  config.include PerformanceHelpers::FrontPageSeed, performance: true
end
