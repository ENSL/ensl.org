FactoryGirl.define do
  sequence :username do |n|
    "Player#{n}"
  end
  
  sequence :email do |n|
    "player#{n}@ensl.org"
  end

  sequence :steamid do |n|
    "0:1:#{n}"
  end

  factory :user do
    username
    email
    steamid
    firstname "ENSL"
    lastname "Player"
    country "EU"
    raw_password "PasswordABC123"

    factory :user_with_team do
      after(:create) do |user|
        create(:team, founder: user)
      end
    end
  end
end
