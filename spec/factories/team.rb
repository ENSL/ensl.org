FactoryGirl.define do
  factory :team do
    sequence(:name) { |n| "Team ##{n}" }
    
    irc "#team"
    web "http://team.com"
    tag "[TEAM]"
    country "EU"
    comment "We are a team"
  end
end