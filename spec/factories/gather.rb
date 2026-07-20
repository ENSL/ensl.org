# frozen_string_literal: true

FactoryBot.define do
  factory :gather do
    association :category, factory: %i[category game]

    transient do
      maps_count { 0 }
      servers_count { 0 }
    end

    after(:create) do |gather, evaluator|
      create_list(:map, evaluator.maps_count).each { |map| gather.maps << map } if evaluator.maps_count.to_i.positive?

      if evaluator.servers_count.to_i.positive?
        create_list(:server, evaluator.servers_count).each { |server| gather.servers << server }
      end
    end

    trait :running do
      status { Gather::STATE_RUNNING }
    end

    trait :picking do
      status { Gather::STATE_PICKING }
    end

    trait :front_page_dataset do
      transient do
        author { create(:user) }
        gathers_count { 100 }
        gatherers_count { 1000 }
        now { Time.current }
        ns1_category { create(:category, :game, name: 'NS1', sort: 10) }
        ns2_category { create(:category, :game, name: 'NS2', sort: 11) }
      end

      after(:create) do |_gather, evaluator|
        gather_rows = Array.new(evaluator.gathers_count) do |index|
          {
            category_id: (index.even? ? evaluator.ns1_category.id : evaluator.ns2_category.id),
            status: Gather::STATE_RUNNING,
            created_at: evaluator.now,
            updated_at: evaluator.now
          }
        end
        Gather.insert_all!(gather_rows) if gather_rows.any?

        gather_ids = Gather.order(id: :desc).limit(evaluator.gathers_count).pluck(:id)
        next if gather_ids.empty? || evaluator.gatherers_count.zero?

        users_per_gather = [(evaluator.gatherers_count.to_f / gather_ids.length).ceil, 1].max
        user_pool = [evaluator.author] + create_list(:user, [users_per_gather - 1, 0].max)

        rows = []
        gather_ids.each do |gather_id|
          user_pool.each do |user|
            break if rows.length >= evaluator.gatherers_count

            rows << { gather_id: gather_id, user_id: user.id, created_at: evaluator.now, updated_at: evaluator.now }
          end
          break if rows.length >= evaluator.gatherers_count
        end
        Gatherer.insert_all!(rows) if rows.any?
      end
    end
  end
end
