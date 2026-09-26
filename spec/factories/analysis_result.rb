# frozen_string_literal: true

FactoryBot.define do
  factory :analysis_result do
    batch_id { 1 }
    model { 'os' }
    digest { SecureRandom.random_bytes(16) }
    field { 'skill_os' }
    value { 25.0 }
    text_value { nil }
  end
end
