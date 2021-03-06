Ensl::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb

  # Code is not reloaded between requests
  config.cache_classes = true

  # Full error reports are disabled and caching is turned on
  config.consider_all_requests_local = false
  config.action_controller.perform_caching = true

  # Disable Rails's static asset server (Apache or nginx will already do this)
  config.serve_static_assets = false

  # Compress JavaScripts and CSS
  config.assets.compress = true

  # Don't fallback to assets pipeline if a precompiled asset is missed
  config.assets.compile = true

  # Generate digests for assets URLs
  config.assets.digest = true

  # Defaults to Rails.root.join("public/assets")
  # config.assets.manifest = YOUR_PATH

  # Specifies the header that your server uses for sending files
  config.action_dispatch.x_sendfile_header = "X-Sendfile" # for apache
  # config.action_dispatch.x_sendfile_header = 'X-Accel-Redirect' # for nginx

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  config.force_ssl = false

  # See everything in the log (default is :info)
  config.log_level = :error

  # Use a different logger for distributed setups
  config.logger = Logger.new(Rails.root.join("log", Rails.env + ".log" ), 5 , 10 * 1024 * 1024)

  # Use a different cache store in production
  config.cache_store = :dalli_store, 'memcached:11211', 'localhost'

  # Enable serving of images, stylesheets, and JavaScripts from an asset server
  # config.action_controller.asset_host = "http://assets.example.com"

  # Precompile additional assets (application.js, application.css, and all non-JS/CSS are already added)
  # config.assets.precompile += %w( search.js )

  # Disable delivery errors, bad email addresses will be ignored
  # config.action_mailer.raise_delivery_errors = false

  # Use smtp-Server
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = {
    address: 'smtp',
    domain: 'ensl.org'
  }

  config.action_mailer.raise_delivery_errors = true

  # Enable threaded mode
  config.threadsafe!

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation can not be found)
  config.i18n.fallbacks = true

  # Send deprecation notices to registered listeners
  config.active_support.deprecation = :notify

  # Custom Session Store config to allow gathers.staging.ensl.org
  config.session_store :cookie_store, key: "_ENSL_session_key", expire_after: 30.days.to_i, domain: ".ensl.org"

#  config.cache_store = :dalli_store, 'cache', 'cache-2.example.com:11211:2',
#  { :namespace => NAME_OF_RAILS_APP, :expires_in => 1.day, :compress => true }
end
