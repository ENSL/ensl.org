FactoryGirl.define do
  factory :contest do
    sequence(:name) { |n| "Contest ##{n}" }

    start Date.yesterday
    self.end Date.tomorrow
    status Contest::STATUS_PROGRESS
    default_time "12:00:00"
  end
end
