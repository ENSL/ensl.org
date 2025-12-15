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
        rand(1..15).times do
          post = build :post, :with_content
          post.topic = topic
          post.save
        end
      end
    end
  end
end
