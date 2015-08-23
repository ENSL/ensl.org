FactoryGirl.define do
  factory :post do
    sequence(:text) { |n| "Post Body #{n}" }
    topic
    user
  end
end
