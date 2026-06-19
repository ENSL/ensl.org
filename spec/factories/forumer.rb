# frozen_string_literal: true

FactoryBot.define do
  factory :forumer do
    forum
    group
    access Forumer::ACCESS_TOPIC
  end
end
