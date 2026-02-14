# frozen_string_literal: true

class Rack::Attack
  # Cache backend
  cache.store = ActiveSupport::Cache::MemoryStore.new # Use Redis cache store in production

  # Whitelist requests from localhost
  safelist('allow-localhost') do |req|
    ['127.0.0.1', '::1'].include?(req.ip)
  end

  # --- Rate Limiting Rules ---

  # Throttle login attempts
  # Limit to 20 requests per 20 minutes per IP
  throttle('logins/ip', limit: 20, period: 20.minutes) do |req|
    req.ip if req.path == '/users/login' && req.post?
  end

  # Throttle login attempts per username
  # Limit to 20 requests per 20 minutes per username
  throttle('logins/username', limit: 20, period: 20.minutes) do |req|
    req.params['login']['username'].presence if req.path == '/users/login' && req.post?
  end

  # Throttle API requests
  # Limit to 300 requests per 5 minutes per IP
  throttle('api/ip', limit: 300, period: 5.minutes) do |req|
    req.ip if req.path.start_with?('/api')
  end

  # Throttle PHP probing
  # Limit to 5 requests per 10 minutes per IP
  throttle('php/ip', limit: 5, period: 10.minutes) do |req|
    req.ip if req.path.include?('.php') || req.path.start_with?('/php')
  end

  # Throttle general requests
  # Limit to 100 requests per 1 minute per IP (catch aggressive scrapers/bots)
  # throttle('req/ip', limit: 100, period: 1.minute) do |req|
  #  req.ip
  # end

  # --- Response Configuration ---

  self.throttled_responder = lambda { |_req|
    [429, {}, [%({"error":"Throttled"})]]
  }

  # Log throttled requests
  self.throttled_response_retry_after_header = true
end

# Enable rack-attack in all environments except test
Rack::Attack.enabled = !Rails.env.test?
