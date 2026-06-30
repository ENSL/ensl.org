# frozen_string_literal: true

FactoryBot.define do
  factory :week do
    sequence(:name) { |n| "Week ##{n}" }
    start_date { Time.zone.today }
    contest
    map1 { create(:map) }
    map2 { create(:map) }
  end
end
