FactoryBot.define do
  factory :category do
    sequence(:name) { |n| "Category #{n}" }
    sequence(:sort) { |n| n }
    domain { Category::DOMAIN_ARTICLES }
  end

  trait :news do
    domain { Category::DOMAIN_NEWS }
  end

  trait :game do
    domain { Category::DOMAIN_GAMES }
  end

  trait :forums do
    domain { Category::DOMAIN_FORUMS }
  end

  trait :articles do
    domain { Category::DOMAIN_ARTICLES }
  end

  trait :movies do
    domain { Category::DOMAIN_MOVIES }
  end
end
