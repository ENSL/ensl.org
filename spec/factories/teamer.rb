# frozen_string_literal: true

FactoryBot.define do
  factory :teamer do
    user
    team
    rank { Teamer::RANK_JOINER }
  end
end
