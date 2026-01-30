# Legacy session compatibility: accept old cookie signing secret from Rails 3.2
Rails.application.config.action_dispatch.cookies_rotations.tap do |cookies|
  old_secret = ENV['APP_SECRET'].to_s

  # Rotate old signed cookies (Rails 3.2)
  cookies.rotate :signed, old_secret, digest: 'SHA1' if old_secret.present?
end
