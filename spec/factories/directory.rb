FactoryBot.define do
  factory :directory do
    sequence(:name) { |n| "dir#{n}" }
    title { 'Test Directory' }
    description { 'A test directory' }
    hidden { false }
    sequence(:path) { |n| "/tmp/test_dirs/dir#{n}" }

    # Create actual directories on disk
    after(:build) do |directory|
      FileUtils.mkdir_p(directory.path) unless File.exist?(directory.path)
    end

    after(:create) do |directory|
      FileUtils.mkdir_p(directory.path) unless File.exist?(directory.path)
    end

    trait :hidden do
      hidden { true }
    end

    trait :root do
      id { Directory::ROOT }
      name { 'root' }
      path { '/tmp/test_dirs/root' }
      parent { nil }
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
