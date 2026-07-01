# frozen_string_literal: true

FactoryBot.define do
  factory :forum do
    sequence(:title) { |n| "Forum Title #{n}" }
    sequence(:description) { |n| "Forum Description #{n}" }

    before :create do |forum|
      cat = create(:category, :forums)
      forum.category = cat
    end

    trait :with_content do
      after :create do |forum|
        rand(5..20).times do
          create(:topic, :with_content, forum: forum)
        end
      end
    end

    trait :front_page_dataset do
      transient do
        author { create(:user) }
        topics_count { 100 }
        posts_count { 1000 }
        now { Time.current }
        category { create(:category, :forums, name: 'Performance Forum Category', sort: 1) }
      end

      after(:create) do |forum, evaluator|
        forum.update!(category: evaluator.category)

        topics = Array.new(evaluator.topics_count) do |index|
          create(:topic,
                 forum: forum,
                 user: evaluator.author,
                 title: "Performance Topic #{index}",
                 first_post: 'Topic seed post',
                 created_at: evaluator.now,
                 updated_at: evaluator.now)
        end

        topic_ids = topics.map(&:id)
        next if topic_ids.empty? || evaluator.posts_count.zero?

        post_rows = Array.new(evaluator.posts_count) do |index|
          {
            topic_id: topic_ids[index % topic_ids.length],
            user_id: evaluator.author.id,
            text: 'Performance post body',
            created_at: evaluator.now,
            updated_at: evaluator.now
          }
        end
        Post.insert_all!(post_rows)
      end
    end
  end
end
