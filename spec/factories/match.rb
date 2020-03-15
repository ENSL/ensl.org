FactoryBot.define do
  factory :match do
    contest
    contester1 do
      create(:contester, contest: contest)
    end
    contester2 do
      create(:contester, contest: contest)
    end

    match_time 1.hour.from_now
  end
end
