require_relative 'boot'

require 'rails/all'

# Bundler.require(*Rails.groups(assets: %w(development test)))
Bundler.require(*Rails.groups)

# FIXME
ActionController::Parameters.permit_all_parameters = true

module Ensl
  class Application < Rails::Application
    # Custom error pages
    config.exceptions_app = self.routes

    # Load Rails 5
    # config.load_defaults 5.0

    # Additional assets
    config.assets.precompile += ["themes/*/theme.css", "themes/*/errors.css"]
    config.assets.initialize_on_precompile = false

    # Custom directories with classes and modules you want to be autoloadable.
    config.autoload_paths += Dir["#{config.root}/app/services/**/", "#{config.root}/app/models/concerns/"]

    # Load secrets from .env
    config.secret_token = ENV['APP_SECRET']

    # Use cookies
    config.session_store :cookie_store, key: '_ENSL_session_key', expire_after: 30.days.to_i

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    config.time_zone = 'Amsterdam'

    # Configure the default encoding used in templates for Ruby 1.9.
    config.encoding = "utf-8"

    # Configure sensitive parameters which will be filtered from the log file.
    config.filter_parameters += [:password]

    # Enable the asset pipeline
    config.assets.enabled = true

    # il8n fix
    config.i18n.fallbacks = true
    config.i18n.enforce_available_locales = false

    # Version of your assets, change this if you want to expire all your assets
    config.assets.version = '1.0'

    # Tiny mce
    config.tinymce.install = :copy
  end
end
