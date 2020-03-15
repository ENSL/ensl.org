FactoryBot.define do
  factory :article do
    sequence(:title) { |n| "Article #{n}" }
    sequence(:text)  { (0..100).map { (0...8).map { (65 + rand(26)).chr }.join }.join(" ") }
  end
end
