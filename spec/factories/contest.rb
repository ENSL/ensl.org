FactoryBot.define do
  factory :contest do
    sequence(:name) { |n| "Contest ##{n}" }
    start { 1.day.ago }
    add_attribute(:end) { 1.day.from_now }
    status { Contest::STATUS_OPEN }
    default_time { "12:00:00" }
  end
end
