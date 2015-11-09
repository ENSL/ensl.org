FactoryGirl.define do
  factory :issue do
    sequence(:title) { |n| "Issue title #{n}" }
    sequence(:text) { |n| "Issue Text #{n}" }
    status Issue::STATUS_OPEN
    association :author, factory: :user
  end
end
