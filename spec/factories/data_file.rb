# frozen_string_literal: true

FactoryBot.define do
  factory :data_file do
    title { 'Test file title' }
    description { '' }
    sequence(:md5) { |n| Digest::MD5.hexdigest("unique_content_#{n}") }
    size { 1024 }
    skip_file_validation { true } # Skip CarrierWave validation for tests

    # For tests, skip CarrierWave processing by setting name column directly
    # This works because tests stub location method
    after(:build) do |data_file|
      # Determine filename
      filename = if data_file.path.present?
                   File.basename(data_file.path)
                 else
                   "test_#{data_file.object_id}.txt"
                 end

      # Set name column directly, bypassing CarrierWave
      # The column just stores the filename
      data_file[:name] = filename

      # Ensure path is set
      data_file.path ||= File.join(Directory.files_root, filename)
    end

    trait :with_directory do
      association :directory
    end

    trait :with_article do
      association :article
    end

    trait :movie do
      title { 'Test movie' }
      association :directory, :movies

      after(:build) do |data_file|
        data_file[:name] = 'test_movie.mp4'
        data_file.path = File.join(data_file.directory.full_path, 'test_movie.mp4') if data_file.directory
      end
    end

    trait :preview do
      title { 'Test preview' }
      association :directory, :movies

      after(:build) do |data_file|
        data_file[:name] = 'test_preview.mp4'
        data_file.path = File.join(data_file.directory.full_path, 'test_preview.mp4') if data_file.directory
      end
    end

    trait :with_related do
      association :related, factory: :data_file
    end

    trait :demo do
      title { 'Test demo' }

      after(:build) do |data_file|
        data_file[:name] = 'test_demo.dem'
        data_file.path ||= File.join(Directory.files_root, 'test_demo.dem')
      end
    end
  end
end
