FactoryBot.define do
  factory :shoutmsg do
    association :user
    sequence(:text) { |n| "shout-#{n}-#{SecureRandom.hex(3)}" }
    shoutable_type { nil }
    shoutable_id { nil }
  end
end
