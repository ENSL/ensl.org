# frozen_string_literal: true

sidekiq_redis_url = ENV.fetch('REDIS_URL', 'redis://redis:6379/1')

Sidekiq.configure_server do |config|
  config.redis = { url: sidekiq_redis_url }

  config.on(:startup) do
    next unless defined?(Sidekiq::Cron::Job)

    Sidekiq::Cron::Job.create(
      name: 'Server metadata sync - every 5 min',
      cron: '*/5 * * * *',
      class: 'ServerMetadataSyncJob'
    )
  end
end

Sidekiq.configure_client do |config|
  config.redis = { url: sidekiq_redis_url }
end
