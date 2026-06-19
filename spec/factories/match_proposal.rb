# frozen_string_literal: true

FactoryBot.define do
  factory :match_proposal do
    match
    team
    proposed_time { 1.day.from_now }
    status { MatchProposal::STATUS_PENDING }

    trait :pending do
      status { MatchProposal::STATUS_PENDING }
    end

    trait :confirmed do
      status { MatchProposal::STATUS_CONFIRMED }
    end

    trait :revoked do
      status { MatchProposal::STATUS_REVOKED }
    end

    trait :rejected do
      status { MatchProposal::STATUS_REJECTED }
    end

    trait :delayed do
      status { MatchProposal::STATUS_DELAYED }
    end

    trait :in_near_future do
      proposed_time { 1.hour.from_now }
    end

    trait :in_far_future do
      proposed_time { 2.days.from_now }
    end

    trait :in_past do
      proposed_time { 1.hour.ago }
    end
  end
end
