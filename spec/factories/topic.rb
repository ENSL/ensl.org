# frozen_string_literal: true

FactoryBot.define do
  factory :topic do
    sequence(:title) { |n| "Topic Title #{n}" }
    forum
    user
    before(:create) do |topic|
      topic.first_post = 'My first post on the topic'
    end

    trait :with_content do
      after :create do |topic|
        rand(1..5).times do
          create(:post, :with_content, topic: topic)
        end
      end
    end
  end
end
