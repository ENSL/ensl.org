FactoryBot.define do
  factory :bracketer do
    bracket
    row { 1 }
    column { 1 }
    match_id { nil }
    team_id { nil }
  end
end
