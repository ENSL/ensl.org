# frozen_string_literal: true

FactoryBot.define do
  factory :vote do
    association :user
    votable { create(:gatherer) }
    votable_type { 'Gatherer' }
  end
end
