# frozen_string_literal: true

FactoryBot.define do
  factory :movie do
    sequence(:name) { |n| "Test Movie #{n}" }
    content { 'A test movie content' }
    format { 'h264' }
    length { 300 } # 5 minutes in seconds
    web_friendly { true }
    status { 0 }

    association :user
    category { association :category, domain: Category::DOMAIN_MOVIES }
    file { association :data_file, :movie }

    trait :with_preview do
      preview { association :data_file, :preview }
    end

    trait :with_match do
      association :match
    end

    trait :long_movie do
      length { 3600 } # 1 hour
    end

    trait :short_movie do
      length { 60 } # 1 minute
    end

    trait :not_web_friendly do
      web_friendly { false }
    end

    trait :with_snapshot do
      picture { 'test_snapshot.png' }
    end

    trait :with_rating do
      transient do
        rating_score { 5 }
      end

      after(:create) do |movie, evaluator|
        rate = create(:rate, score: evaluator.rating_score)
        create(:rating, rateable: movie.file, rate: rate)
      end
    end
  end
end
