# frozen_string_literal: true

FactoryBot.define do
  factory :article do
    association :user
    association :category
    sequence(:title) { |n| "Article #{n}" }
    sequence(:text)  { (0..100).map { (0...8).map { rand(65..90).chr }.join }.join(' ') }
    text_coding { Article::CODING_MARKDOWN }
    status { Article::STATUS_PUBLISHED }

    trait :front_page_dataset do
      transient do
        news_category { create(:category, :news, name: 'Performance News', sort: 0) }
        author { create(:user) }
        articles_count { 100 }
        comments_count { 300 }
        now { Time.current }
      end

      before(:create) do |article, evaluator|
        article.category ||= evaluator.news_category
        article.user ||= evaluator.author
      end

      after(:create) do |_article, evaluator|
        article_rows = Array.new(evaluator.articles_count) do |index|
          created_at = evaluator.now - index.minutes
          {
            category_id: evaluator.news_category.id,
            user_id: evaluator.author.id,
            title: "Performance Article #{index}",
            text: 'Generated performance article body',
            text_coding: Article::CODING_BBCODE,
            status: Article::STATUS_PUBLISHED,
            created_at: created_at,
            updated_at: created_at
          }
        end
        Article.insert_all!(article_rows) if article_rows.any?

        article_ids = Article.where(category_id: evaluator.news_category.id)
                             .order(id: :desc)
                             .limit(evaluator.articles_count)
                             .pluck(:id)
        next if article_ids.empty? || evaluator.comments_count.zero?

        comment_rows = Array.new(evaluator.comments_count) do |index|
          {
            commentable_type: 'Article',
            commentable_id: article_ids[index % article_ids.length],
            user_id: evaluator.author.id,
            text: 'Generated performance comment',
            created_at: evaluator.now,
            updated_at: evaluator.now
          }
        end
        Comment.insert_all!(comment_rows)
      end
    end
  end
end
