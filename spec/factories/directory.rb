# frozen_string_literal: true

FactoryBot.define do
  factory :directory do
    sequence(:name) { |n| "dir#{n}" }
    title { 'Test Directory' }
    description { 'A test directory' }
    hidden { false }
    parent { nil }

    # Don't set path - let model compute it via ensure_path_cached
    # Don't pre-create directories - let model's make_path callback handle it

    trait :hidden do
      hidden { true }
    end

    trait :root do
      id { Directory::ROOT }
      name { 'root' }
      parent { nil }
      # path will be set to ENV['FILES_ROOT'] by ensure_path_cached
    end

    trait :movies do
      id { Directory::MOVIES }
      name { 'movies' }
      association :parent, factory: :directory
    end

    trait :articles do
      id { Directory::ARTICLES }
      name { 'articles' }
      association :parent, factory: :directory
    end

    trait :with_parent do
      association :parent, factory: :directory
    end
  end
end
