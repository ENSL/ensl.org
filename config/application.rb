require 'logger'
require_relative 'boot'
require 'securerandom'
require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
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
    config.exceptions_app = ->(env) { Rails.application.routes.call(env) }

    # Secret key
    config.require_master_key = false

    # Load Rails 5
    config.load_defaults 5.0

    # Additional assets
    config.assets.precompile += ['themes/*/theme.css', 'themes/*/errors.css']
    config.assets.initialize_on_precompile = false

    # Custom directories with classes and modules you want to be autoloadable.
    # Only register the services root (no recursive dirs as roots)
    services_root = Rails.root.join('app', 'services').to_s
    # Remove any previously added nested service dirs (cleanup)
    nested_service_dirs = Dir[File.join(services_root, '**/')]
    config.autoload_paths -= nested_service_dirs
    config.eager_load_paths -= nested_service_dirs

    config.autoload_paths = (config.autoload_paths + [services_root,
                                                      Rails.root.join('app', 'models', 'concerns').to_s]).uniq
    config.eager_load_paths = (config.eager_load_paths + [services_root]).uniq

    # Be sure to restart your server when you modify this file.
    config.session_store :cookie_store,
                         key: '_ENSL_session_key',
                         domain: (Rails.env.production? ? '.ensl.org' : nil),
                         secure: Rails.env.production?,
                         same_site: :lax,
                         expire_after: 6.months

    config.action_dispatch.cookies_serializer = :hybrid

    # Load secrets from .env
    ENV['APP_SECRET'] = ENV['APP_SECRET'].to_s
    ENV['APP_SECRET'] = SecureRandom.hex(64) if ENV['APP_SECRET'].empty?
    config.secret_token = ENV['APP_SECRET']
    config.secret_key_base = ENV['APP_SECRET']

    # Use a different cache store
    config.cache_store = :mem_cache_store, 'memcached:11211'

    # Use smtp-Server
    config.action_mailer.delivery_method = :smtp
    config.action_mailer.smtp_settings = {
      address: 'smtp',
      domain: ENV['MAIL_DOMAIN']
    }

    # Use a different logger for distributed setups
    config.logger = Logger.new(Rails.root.join('log', Rails.env + '.log'), 5, 10 * 1024 * 1024)

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    config.time_zone = 'Amsterdam'

    # Configure the default encoding used in templates for Ruby 1.9.
    config.encoding = 'utf-8'

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
