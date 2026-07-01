# frozen_string_literal: true

FactoryBot.define do
  factory :read_mark do
    reader_type { 'User' }
    association :reader, factory: :user
    readable_type { 'Message' }
    readable_id { nil }
    timestamp { Time.current }
  end
end
