FactoryGirl.define do
	factory :message do
		association :sender, factory: :user
		association :recipient, factory: :user
		sequence(:text)    { |n| "text-#{n}" }
		sequence(:title)    { |n| "title-#{n}" }
		sequence(:text_parsed)    { |n| "text-#{n}" }
	end
end