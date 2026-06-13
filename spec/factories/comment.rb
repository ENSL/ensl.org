FactoryBot.define do
  factory :comment do
    association :user
    association :commentable, factory: :article
    sequence(:text) { |n| "This is comment body number #{n}." }
  end
end
