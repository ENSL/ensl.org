FactoryBot.define do
  factory :user do
    sequence(:username) { |n| "Player#{SecureRandom.hex(8)}" }
    sequence(:email)    { |n| "player#{SecureRandom.hex(8)}@ensl.org" }
    sequence(:steamid)  { |n| "0:1:#{Time.now.to_i * 1000 + n + SecureRandom.random_bytes(4).unpack1('N')}" }

    firstname 'ENSL'
    lastname 'Player'
    country 'EU'
    raw_password 'PasswordABC123'
    # lastvisit "Sun, 15 Mar 2020 13:31:06 +0000"

    trait :admin do
      after(:create) do |user|
        group = Group.find_or_create_by(id: Group::ADMINS) do |record|
          record.name = 'Admins'
          record.founder = user
        end
        create :grouper, user: user, group: group
      end
    end

    trait :caster do
      after(:create) do |user|
        group = Group.find_or_create_by(id: Group::CASTERS) do |record|
          record.name = 'Shoutcasters'
          record.founder = user
        end
        create :grouper, user: user, group: group
      end
    end

    trait :gather_moderator do
      after(:create) do |user|
        group = Group.find_or_create_by(id: Group::GATHER_MODERATORS) do |record|
          record.name = 'Gather Moderator'
          record.founder = user
        end
        create :grouper, user: user, group: group
      end
    end

    trait :ref do
      after(:create) do |user|
        group = Group.find_or_create_by(id: Group::REFEREES) do |record|
          record.name = 'Referees'
          record.founder = user
        end
        create :grouper, user: user, group: group
      end
    end

    trait :referee do
      after(:create) do |user|
        group = Group.find_or_create_by(id: Group::REFEREES) do |record|
          record.name = 'Referees'
          record.founder = user
        end
        create :grouper, user: user, group: group
      end
    end

    trait :movie_maker do
      after(:create) do |user|
        group = Group.find_or_create_by(id: Group::MOVIES) { |g| g.name = 'Movie Makers' }
        create :grouper, user: user, group: group
      end
    end

    trait :chris do
      steamid '0:1:58097444'
    end

    factory :user_with_team do
      after(:create) do |user|
        create(:team, founder: user)
      end
    end
  end
end
