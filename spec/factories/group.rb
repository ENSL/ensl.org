FactoryBot.define do
  factory :group do
    sequence(:id) { |n| n + 100 } # Preserve first 100
    sequence(:name) { |n| "Group#{n}" }
    association :founder, factory: :user

    # initialize_with { Group.find_or_create_by(id: id) }
  end

  trait :admin do
    name "Admins"
    id Group::ADMINS
  end

  trait :caster do
    name "Shoutcasters"
    id Group::CASTERS
  end

  trait :champions do
    name "Champions"
    id Group::CHAMPIONS
  end

  trait :donors do
    name "Donors"
    id Group::DONORS
  end

  trait :gather_moderator do
    name "Gather Moderator"
    id Group::GATHER_MODERATORS
  end

  trait :ref do
    name "Referees"
    id Group::REFEREES
  end
end
