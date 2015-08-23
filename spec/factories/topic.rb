FactoryGirl.define do
  factory :topic do
    sequence(:title) { |n| "Topic Title #{n}" }
    forum
    user
    before(:create) do |topic|
      topic.first_post = "My first post on the topic"
    end
  end
end
