FactoryBot.define do
  factory :team do
    sequence(:name) { |n| "Team #{n}-#{Time.now.to_i}" }
    sequence(:tag) { |n| "[T#{n}]" }

    irc '#team'
    web 'http://team.com'
    country 'EU'
    comment 'We are a team'

    trait :with_members do
      transient do
        members_count { 6 }
      end

      after(:create) do |team, evaluator|
        # Create unique users for this team
        evaluator.members_count.times do |i|
          user = create(:user)
          create(:teamer, user: user, team: team, rank: Teamer::RANK_MEMBER)
        end
      end
    end
  end
end
