FactoryGirl.define do
  factory :topic do
    sequence(:title) { |n| "Forum Title #{n}" }
  end
end