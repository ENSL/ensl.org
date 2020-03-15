FactoryBot.define do
  factory :map do
    sequence(:name) { |n| "ns_MapName#{n}" }
  end
end
