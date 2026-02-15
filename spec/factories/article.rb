FactoryBot.define do
  factory :article do
    association :user
    association :category
    sequence(:title) { |n| "Article #{n}" }
    sequence(:text)  { (0..100).map { (0...8).map { rand(65..90).chr }.join }.join(' ') }
    text_coding { Article::CODING_BBCODE }
    status { Article::STATUS_PUBLISHED }
  end
end
