FactoryBot.define do
  factory :forumer do
    forum
    group
    access Forumer::ACCESS_TOPIC
  end
end
