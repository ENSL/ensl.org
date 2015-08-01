FactoryGirl.define do
  factory :ban do
    ban_type Ban::TYPE_SITE
    expiry Date.today + 1
    # Hack because of the awkward way bans are created (requires user_name)
    before(:create) do |ban|
      if ban.user.nil?
        user = create :user
        ban.user_name = user.username
      else 
        ban.user_name = ban.user.username
      end
    end
  end

  trait :mute do
    ban_type Ban::TYPE_MUTE
  end

  trait :site do
    ban_type Ban::TYPE_SITE
  end

  trait :gather do
    ban_type Ban::TYPE_GATHER
  end

  trait :expired do
    expiry Date.yesterday - 1
  end
end