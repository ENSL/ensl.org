FactoryGirl.define do
	factory :server do
		sequence(:name) { |n| "ServerName#{n}" }
		sequence(:dns) { |n| "DNS#{n}" }
		sequence(:ip) { |n| "192.168.#{n % 255}.#{n}" }
		sequence(:port) { |n| "#{1000 + n}" }
	end
end