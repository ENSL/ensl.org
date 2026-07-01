# frozen_string_literal: true

require 'ostruct'

FactoryBot.define do
  factory :front_page_dataset, class: OpenStruct do
    skip_create
    initialize_with { new }

    transient do
      targets { {} }
      now { Time.current }
    end

    after(:build) do |dataset, evaluator|
      author = create(:user, :admin, :front_page_state)

      news_category = create(:category, :news, name: 'Performance News', sort: 0)
      create(:article, :front_page_dataset,
             news_category: news_category,
             author: author,
             articles_count: evaluator.targets[:articles],
             comments_count: evaluator.targets[:comments],
             now: evaluator.now)

      create(:forum, :front_page_dataset,
             author: author,
             topics_count: evaluator.targets[:topics],
             posts_count: evaluator.targets[:posts],
             now: evaluator.now)

      create(:gather, :front_page_dataset,
             author: author,
             gathers_count: evaluator.targets[:gathers],
             gatherers_count: evaluator.targets[:gatherers],
             now: evaluator.now)

      create(:contest, :front_page_dataset,
             author: author,
             teams_count: evaluator.targets[:teams],
             contesters_count: evaluator.targets[:contesters],
             matches_count: evaluator.targets[:matches],
             now: evaluator.now,
             name: 'Performance Contest',
             short_name: 'PERF',
             status: Contest::STATUS_OPEN,
             default_time: '20:00:00',
             start: evaluator.now - 7.days,
             end: evaluator.now + 30.days)

      create(:shoutmsg, :front_page_dataset,
             author: author,
             shoutmsgs_count: evaluator.targets[:shoutmsgs],
             issues_count: evaluator.targets[:issues],
             messages_count: evaluator.targets[:messages],
             now: evaluator.now)

      create(:poll, :front_page_dataset,
             user: author,
             author: author,
             votes_count: evaluator.targets[:votes],
             question: 'Performance polling question?')

      stats = {
        articles_seeded: evaluator.targets[:articles],
        comments_seeded: evaluator.targets[:comments],
        topics_seeded: evaluator.targets[:topics],
        posts_seeded: evaluator.targets[:posts],
        shoutmsgs_seeded: evaluator.targets[:shoutmsgs],
        gathers_seeded: evaluator.targets[:gathers],
        gatherers_seeded: evaluator.targets[:gatherers],
        teams_seeded: evaluator.targets[:teams],
        contesters_seeded: evaluator.targets[:contesters],
        matches_seeded: evaluator.targets[:matches],
        issues_seeded: evaluator.targets[:issues],
        messages_seeded: evaluator.targets[:messages],
        votes_seeded: evaluator.targets[:votes],
        forums_seeded: Forum.count,
        article_ids_seeded: Article.where(category_id: news_category.id).limit(evaluator.targets[:articles]).count
      }

      stats.each { |key, value| dataset[key] = value }
    end
  end
end
