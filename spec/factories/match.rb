FactoryBot.define do
  factory :match do
    contest
    contester1 do
      create(:contester, contest: contest)
    end
    contester2 do
      create(:contester, contest: contest)
    end

    match_time { 1.hour.from_now }

    trait :scored do
      after(:create) do |match|
        match.update!(
          score1: rand(1..4),
          score2: rand(1..4)
        )
      end
    end

    trait :for_contesters do
      transient do
        contesters { [] }
      end

      contester1 { contesters.sample }
      contester2 { contesters.sample }
    end
  end
end
