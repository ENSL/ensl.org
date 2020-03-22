FactoryBot.define do
  factory :post do
    sequence(:text) { |n| "Post Body #{n}" }
    topic
    user
    
    trait :with_content do
      text { (0..100).map { (0...8).map { (65 + rand(26)).chr }.join }.join(" ") }
    end
  end
end
