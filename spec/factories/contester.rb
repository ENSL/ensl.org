# frozen_string_literal: true

FactoryBot.define do
  factory :contester do
    contest
    team do
      create(:user_with_team).team
    end
  end
end
