FactoryGirl.define do
  factory :forum do
    sequence(:title) { |n| "Forum Title #{n}" }
    sequence(:description) { |n| "Forum Description #{n}" }
  end
end