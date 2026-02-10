FactoryBot.define do
  factory :prediction do
    match
    user
    score1 { 2 }
    score2 { 1 }
  end
end
