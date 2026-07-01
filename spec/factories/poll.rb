# frozen_string_literal: true

FactoryBot.define do
  factory :poll do
    sequence(:question) { |n| "Poll question #{n}" }
    association :user

    transient do
      options_count { 2 }
    end

    after(:build) do |poll, evaluator|
      next if poll.options.any?

      evaluator.options_count.times do |index|
        poll.options.build(option: "Option #{index + 1}")
      end
    end

    trait :front_page_dataset do
      transient do
        author { create(:user) }
        votes_count { 6000 }
      end

      after(:create) do |poll, evaluator|
        option_ids = poll.options.pluck(:id)
        next if option_ids.empty? || evaluator.votes_count.zero?

        users_needed = [(evaluator.votes_count.to_f / option_ids.length).ceil, 1].max
        vote_users = [evaluator.author] + create_list(:user, [users_needed - 1, 0].max)

        rows = vote_users.flat_map do |vote_user|
          option_ids.map do |option_id|
            {
              poll_id: poll.id,
              user_id: vote_user.id,
              votable_type: 'Option',
              votable_id: option_id
            }
          end
        end.first(evaluator.votes_count)

        Vote.insert_all!(rows) if rows.any?
      end
    end
  end
end
