FactoryBot.define do
  factory :bracket do
    contest
    sequence(:name) { |n| "Bracket #{n}" }
    slots { 16 }
  end
end
