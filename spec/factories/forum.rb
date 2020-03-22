FactoryBot.define do
  factory :forum do
    sequence(:title) { |n| "Forum Title #{n}" }
    sequence(:description) { |n| "Forum Description #{n}" }

    before :create do |forum|
      cat = create(:category, :forums)
      forum.category = cat
    end

    trait :with_content do
      after :create do |forum|
        (rand(30..100)).times do
          topic = build :topic, :with_content
          topic.forum = forum
          topic.save
        end
      end
    end
  end
end
