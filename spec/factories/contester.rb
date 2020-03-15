FactoryBot.define do
  factory :contester do
    contest
    team do
      create(:user_with_team).team
    end
  end
end
