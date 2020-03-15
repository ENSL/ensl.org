FactoryBot.define do
  factory :category do
    sequence(:name) { |n| "Category #{n}" }
    sequence(:sort) { |n| n }
  end

  trait :news do
    domain Category::DOMAIN_NEWS
  end

  trait :game do
    domain Category::DOMAIN_GAMES
  end
end
