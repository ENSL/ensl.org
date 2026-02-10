FactoryBot.define do
  factory :gatherer do
    association :gather
    association :user

    status 0
    team nil
    votes 0
  end
end
