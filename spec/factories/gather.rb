FactoryGirl.define do
  factory :gather do
    association :category, factory: [:category, :game]
  end

  trait :running do
  	status Gather::STATE_RUNNING
  end

  trait :picking do
  	status Gather::STATE_PICKING
  end
end
