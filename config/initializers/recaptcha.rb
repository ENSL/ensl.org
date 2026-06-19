# frozen_string_literal: true

Recaptcha.configure do |config|
  # Use ENV vars for keys. Set RECAPTCHA_SITE_KEY and RECAPTCHA_SECRET_KEY in your environment.
  config.site_key = ENV['RECAPTCHA_SITE_KEY']
  config.secret_key = ENV['RECAPTCHA_SECRET_KEY']
  # Uncomment if you are using a proxy
  # config.proxy = 'http://myproxy.com'
end
