FactoryBot.define do
  factory :map do
    sequence(:name) { |n| "ns_MapName#{n}" }

    trait :full do
      sequence(:name) { |n| "ns_FullMap#{n}" }
      download { 'http://example.com/downloads/map_file.zip' }
      category_id do
        create(:category, :game).id
      end
      picture { nil } # Can be set to a fixture file if needed
    end
  end
end
