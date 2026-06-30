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
      status Gather::STATE_RUNNING
    end

    trait :picking do
      status Gather::STATE_PICKING
    end
  end
end
