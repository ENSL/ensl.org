# frozen_string_literal: true

require Rails.root.join('app/middleware/session_bloat_guard')

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :steam, ENV['STEAM_WEB_API_KEY']
end

# Must run before OmniAuth::Builder: it strips session bloat that would otherwise
# push the /auth/steam request's cookie over the 4KB limit before OmniAuth even
# gets a chance to add its own OpenID discovery data (see SessionBloatGuard).
Rails.application.config.middleware.insert_before OmniAuth::Builder, SessionBloatGuard

# OmniAuth configuration for better reliability
OmniAuth.config.logger = Rails.logger

# Ensure the session middleware is used for persisting OpenID state
# This helps prevent nonce validation failures during callback
OmniAuth.config.full_host = Rails.env.production? ? "https://#{ENV['PRODUCTION_DOMAIN']}" : 'http://localhost:4000'
