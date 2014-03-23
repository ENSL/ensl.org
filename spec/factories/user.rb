FactoryGirl.define do
  sequence :username do |n|
    "Player#{n}"
  end
  
  sequence :email do |n|
    "player#{n}@ensl.org"
  end

  factory :user do
    username
    email
    firstname "ENSL"
    lastname "Player"
    steamid "0:1:23456789"
    country "EU"
    raw_password "PasswordABC123"
  end
end