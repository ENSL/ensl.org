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

  desc 'Send a test push notification to a user, e.g. rake web_push:test[username]'
  task :test, [:username] => :environment do |_task, args|
    user = User.find_by(username: args[:username])
    abort "No user named #{args[:username]}" unless user

    delivered = PushNotifications::Deliver.call(
      user_ids: [user.id],
      payload: { title: 'ENSL test', body: 'Push notifications are working.', tag: 'ensl-test', url: '/gather' }
    )

    puts "subscriptions=#{user.push_subscriptions.count} delivered=#{delivered}"
  end
end
