FactoryGirl.define do
  sequence :name do |n|
    "Team ##{n}"
  end

  factory :team do
    name
    irc "#team"
    web "http://team.com"
    tag "[TEAM]"
    country "EU"
    comment "We are a team"
  end
end