Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb

  # Load app models at start
  config.eager_load = true

  # Code is not reloaded between requests
  config.cache_classes = true
  config.action_controller.perform_caching = true

  # Full error reports are disabled and caching is turned on
  config.consider_all_requests_local = false

  # Disable Rails's static asset server (Apache or nginx will already do this)
  config.serve_static_assets = true

  # Compress JavaScripts and CSS
  config.assets.compress = true
  # config.assets.js_compressor = Uglifier.new(harmony: true)

  # Don't fallback to assets pipeline if a precompiled asset is missed
  config.assets.compile = true

  # Generate digests for assets URLs
  config.assets.digest = true

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  # Keep this off, causes weird redirection bug
  config.force_ssl = false

  # See everything in the log (default is :info)
  config.log_level = :error

  # Disable delivery errors, bad email addresses will be ignored
  config.action_mailer.raise_delivery_errors = false

  # Send email
  config.action_mailer.perform_deliveries = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Specifies the header that your server uses for sending files
  # config.action_dispatch.x_sendfile_header = "X-Sendfile" # for apache
  config.action_dispatch.x_sendfile_header = 'X-Accel-Redirect' # for nginx
end
