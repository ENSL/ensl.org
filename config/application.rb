require_relative 'boot'
require 'securerandom'

# FIXME
# Set random value for this
ENV["APP_SECRET_KEY_BASE"] ||= SecureRandom.alphanumeric(32)

require 'rails/all'

# Bundler.require(*Rails.groups(assets: %w(development test)))
Bundler.require(*Rails.groups)

# FIXME
ActionController::Parameters.permit_all_parameters = true

class ActionDispatch::Session::MyCustomStore < ActionDispatch::Session::CookieStore
  private

  def cookie_jar(request)
    request.cookie_jar.signed
  end
end


module Ensl
  class Application < Rails::Application
    # Custom error pages
    config.exceptions_app = self.routes

    # Secret key
    config.require_master_key = false 

    # Load Rails 5
    # config.load_defaults 5.0

    # Additional assets
    config.assets.precompile += ["themes/*/theme.css", "themes/*/errors.css"]
    config.assets.initialize_on_precompile = false

    # Custom directories with classes and modules you want to be autoloadable.
    config.autoload_paths += Dir["#{config.root}/app/services/**/", "#{config.root}/app/models/concerns/"]

    # Be sure to restart your server when you modify this file.
    config.session_store :cookie_store, key: '_ENSL_session_key'
    # config.session_store :my_custom_store, key: '_ENSL_session_key'

    # Load secrets from .env
    ENV['APP_SECRET'] ||= (0...32).map { (65 + rand(26)).chr }.join
    config.secret_token = ENV['APP_SECRET']

    # Use a different cache store
    config.cache_store = :mem_cache_store, 'memcached:11211'

    # Use smtp-Server
    config.action_mailer.delivery_method = :smtp
    config.action_mailer.smtp_settings = {
      address: 'smtp',
      domain: ENV['MAIL_DOMAIN']
    }

    # Use a different logger for distributed setups
    config.logger = Logger.new(Rails.root.join("log", Rails.env + ".log" ), 5 , 10 * 1024 * 1024)

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    config.time_zone = 'Amsterdam'

    # Configure the default encoding used in templates for Ruby 1.9.
    config.encoding = "utf-8"

    # Configure sensitive parameters which will be filtered from the log file.
    config.filter_parameters += [:password]

    # Enable the asset pipeline
    config.assets.enabled = true

    # Version of your assets, change this if you want to expire all your assets
    config.assets.version = '1.0'

    # il8n fix
    config.i18n.fallbacks = true
    config.i18n.enforce_available_locales = false

    # Tiny mce
    config.tinymce.install = :copy

    # Send deprecation notices to registered listeners
    config.active_support.deprecation = :notify

    # Enable threaded mode
    # Almost nothing is thread-safe, do NOT use this
    # config.threadsafe!
  end
end
