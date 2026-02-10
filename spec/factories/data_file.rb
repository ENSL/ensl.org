FactoryBot.define do
  factory :data_file do
    description { 'Test file description' }
    sequence(:path) { |n| "/tmp/test_dirs/testfile#{n}.txt" }
    md5 { 'e948c22100d29623a1df48e1760494df' }
    size { 1024 }

    # Create actual file on disk
    after(:build) do |data_file|
      file_path = data_file.path
      FileUtils.mkdir_p(File.dirname(file_path))
      File.write(file_path, "test content #{data_file.id}") unless File.exist?(file_path)
    end

    after(:create) do |data_file|
      file_path = data_file.path
      FileUtils.mkdir_p(File.dirname(file_path))
      File.write(file_path, "test content #{data_file.id}") unless File.exist?(file_path)
    end

    trait :with_directory do
      association :directory
    end

    trait :with_article do
      association :article
    end

    trait :movie do
      description { 'Test movie' }
      sequence(:path) { |n| "/tmp/test_dirs/test_movie#{n}.mp4" }
      association :directory, :movies
    end

    trait :preview do
      description { 'Test preview' }
      sequence(:path) { |n| "/tmp/test_dirs/test_preview#{n}.mp4" }
      association :directory, :movies
    end

    trait :with_related do
      association :related, factory: :data_file
    end

    trait :demo do
      description { 'Test demo' }
      sequence(:path) { |n| "/tmp/test_dirs/test_demo#{n}.dem" }
    end
  end
end
