FactoryBot.define do
  factory :post do
    sequence(:text) { |n| "Post Body #{n}" }
    topic
    user

    trait :with_content do
      text { (0..7).map { (0...8).map { rand(65..90).chr }.join }.join(' ') }
    end
  end
end
