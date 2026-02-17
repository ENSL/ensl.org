FactoryBot.define do
  factory :rating do
    association :rateable, factory: :data_file
    association :user

    after(:build) do |rating|
      rating.rate ||= build(:rate)
    end
  end
end
