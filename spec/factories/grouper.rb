# frozen_string_literal: true

FactoryBot.define do
  factory :grouper do
    sequence(:task) { |n| "Task#{n}" }
  end
end
