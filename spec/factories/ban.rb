FactoryBot.define do
  factory :ban, class: Ban do
    ban_type { Ban::TYPE_SITE }
    # NOTE: due to time zone difference this causes tests to fail
    # When adding the time, its in previous day and the time is set to 00:00
    # read: http://danilenko.org/2012/7/6/rails_timezones/
    expiry { Time.now.utc + 1.day }
    
    # Hack because of the awkward way bans are created (requires user_name)
    before(:create) do |ban|
      if ban.user.nil?
        user = create :user
        ban.user_name = user.username
      else
        ban.user_name = ban.user.username
      end
    end

    trait :mute do
      ban_type { Ban::TYPE_MUTE }
    end
  
    trait :site do
      ban_type { Ban::TYPE_SITE }
    end
  
    trait :gather do
      ban_type { Ban::TYPE_GATHER }
    end
  
    trait :expired do
      expiry { Time.now.utc - 1.day  }
    end
  end
end
