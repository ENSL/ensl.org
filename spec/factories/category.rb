FactoryGirl.define do
  factory :category do
    sequence(:name) { |n| "Category #{n}" }
    sequence(:sort) { |n| n }
  end
end