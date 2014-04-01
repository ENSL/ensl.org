FactoryGirl.define do
  factory :user do
    sequence(:username) { |n| "Player#{n}" }
    sequence(:email)    { |n| "player#{n}@ensl.org" }
    sequence(:steamid)  { |n| "0:1:#{n}" }

    firstname "ENSL"
    lastname "Player"
    country "EU"
    raw_password "PasswordABC123"

    after(:create) do |user|
      create(:profile, user: user)
    end

    factory :user_with_team do
      after(:create) do |user|
        create(:team, founder: user)
      end
    end
  end
end
