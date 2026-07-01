# frozen_string_literal: true

FactoryBot.define do
  factory :shoutmsg do
    association :user
    sequence(:text) { |n| "shout-#{n}-#{SecureRandom.hex(3)}" }
    shoutable_type { nil }
    shoutable_id { nil }

    trait :front_page_dataset do
      transient do
        author { create(:user) }
        shoutmsgs_count { 1500 }
        issues_count { 2500 }
        messages_count { 4000 }
        now { Time.current }
      end

      after(:create) do |_shoutmsg, evaluator|
        shoutmsg_rows = Array.new(evaluator.shoutmsgs_count) do
          {
            user_id: evaluator.author.id,
            shoutable_type: nil,
            shoutable_id: nil,
            text: 'Performance shout',
            created_at: evaluator.now,
            updated_at: evaluator.now
          }
        end
        Shoutmsg.insert_all!(shoutmsg_rows) if shoutmsg_rows.any?

        issue_rows = Array.new(evaluator.issues_count) do |index|
          {
            author_id: evaluator.author.id,
            title: "Performance issue #{index}",
            text: 'Performance issue body',
            status: Issue::STATUS_OPEN,
            created_at: evaluator.now,
            updated_at: evaluator.now
          }
        end
        Issue.insert_all!(issue_rows) if issue_rows.any?

        message_rows = Array.new(evaluator.messages_count) do |index|
          {
            sender_type: 'User',
            sender_id: evaluator.author.id,
            recipient_type: 'User',
            recipient_id: evaluator.author.id,
            title: "Performance message #{index}",
            text: 'Performance message body',
            created_at: evaluator.now,
            updated_at: evaluator.now
          }
        end
        Message.insert_all!(message_rows) if message_rows.any?
      end
    end
  end
end
