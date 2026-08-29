# frozen_string_literal: true

namespace :web_push do
  desc 'Generate a VAPID keypair for web push notifications'
  task generate_keys: :environment do
    key = WebPush.generate_key

    puts 'Add these to your environment (e.g. .env), then restart the app and Sidekiq:'
    puts "VAPID_PUBLIC_KEY=#{key.public_key}"
    puts "VAPID_PRIVATE_KEY=#{key.private_key}"
    puts 'VAPID_SUBJECT=mailto:staff@ensl.org'
  end
end
