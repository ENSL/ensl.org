Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb

  # Load app models at start
  config.eager_load = true

  # Code is not reloaded between requests
  config.cache_classes = true
  config.action_controller.perform_caching = true

  # Full error reports are disabled and caching is turned on
  config.consider_all_requests_local = false

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  # Keep this off, causes weird redirection bug
  config.force_ssl = false

  # Trust SSL terminated at the proxy so request.base_url uses https
  config.assume_ssl = false

  # See everything in the log (default is :info)
  config.log_level = (ENV['LOG_LEVEL'] || 'error').to_sym

  # Log one JSON event per request
  config.lograge.enabled = true
  config.lograge.formatter = Lograge::Formatters::Json.new
  config.lograge.keep_original_rails_log = false
  lograge_logger = ActiveSupport::Logger.new(Rails.root.join('log', "#{Rails.env}.log"), 5, 10 * 1024 * 1024)
  lograge_logger.formatter = proc { |_severity, _timestamp, _progname, msg| "#{msg}\n" }
  config.lograge.logger = ActiveSupport::TaggedLogging.new(lograge_logger)
  config.lograge.custom_payload do |controller|
    request = controller.request
    {
      request_id: request.request_id,
      user_id: controller.respond_to?(:cuser) ? controller.cuser&.id : nil,
      ip: request.remote_ip,
      user_agent: request.user_agent,
      method: request.request_method,
      path: request.fullpath
    }
  end

  # Disable delivery errors, bad email addresses will be ignored
  config.action_mailer.raise_delivery_errors = false

  # Send email
  config.action_mailer.perform_deliveries = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Specifies the header that your server uses for sending files
  # config.action_dispatch.x_sendfile_header = "X-Sendfile" # for apache
  config.action_dispatch.x_sendfile_header = 'X-Accel-Redirect' # for nginx

  # Secret key
  config.require_master_key = false
end
