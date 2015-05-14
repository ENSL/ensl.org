FactoryGirl.define do
  factory :group do
  	sequence(:id) { |n| n + 100 } # Preserve first 100
    sequence(:name) { |n| "Group#{n}" }
    association :founder, factory: :user
  end

  trait :admin do
  	name "Admins"
  	id Group::ADMINS
  end
end
