# frozen_string_literal: true

# Configure OmniAuth failure handling - log errors and redirect gracefully
OmniAuth.config.on_failure = proc do |env|
  request = Rack::Request.new(env)
  error_type = env['omniauth.error.type']
  error_message = env['omniauth.error']

  Rails.logger.error(
    "OmniAuth Callback Failure: #{error_type} - #{error_message}\n" \
    "Strategy: #{env['omniauth.error.strategy']}\n" \
    "IP: #{request.ip}"
  )

  # Redirect to login page with error parameter
  [
    302,
    { 'Location' => '/users/new?steam_login_failed=true' },
    ['Steam login failed. Please try again.']
  ]
end
