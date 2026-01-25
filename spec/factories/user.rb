FactoryBot.define do
  factory :user do
    sequence(:username) { |n| "Player#{n}" }
    sequence(:email)    { |n| "player#{n}@ensl.org" }
    sequence(:steamid)  { |n| "STEAM_0:1:#{n + 1}" }

    firstname 'ENSL'
    lastname 'Player'
    country 'EU'
    raw_password 'PasswordABC123'
    # lastvisit "Sun, 15 Mar 2020 13:31:06 +0000"

    trait :admin do
      after(:create) do |user|
        group = create(:group, :admin)
        create :grouper, user: user, group: group
      end
    end

    trait :caster do
      after(:create) do |user|
        group = create(:group, :caster)
        create :grouper, user: user, group: group
      end
    end

    trait :ref do
      after(:create) do |user|
        group = create(:group, :ref)
        create :grouper, user: user, group: group
      end
    end

    trait :chris do
      steamid 'STEAM_0:1:58097444'
    end

    factory :user_with_team do
      after(:create) do |user|
        create(:team, founder: user)
      end
    end
  end
end
