FactoryBot.define do
  factory :week do
    sequence(:name) { |n| "Week ##{n}" }
    start_date { Date.today }
    contest
    map1 { create(:map) }
    map2 { create(:map) }
  end
end
