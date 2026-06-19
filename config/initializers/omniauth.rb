# frozen_string_literal: true

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :steam, ENV['STEAM_WEB_API_KEY']
end

# OmniAuth configuration for better reliability
OmniAuth.config.logger = Rails.logger

# Ensure the session middleware is used for persisting OpenID state
# This helps prevent nonce validation failures during callback
OmniAuth.config.full_host = Rails.env.production? ? "https://#{ENV['PRODUCTION_DOMAIN']}" : 'http://localhost:4000'
