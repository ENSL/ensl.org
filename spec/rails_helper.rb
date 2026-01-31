# Load spec_helper
require 'spec_helper'

ENV['RAILS_ENV'] ||= 'test'
require File.expand_path('../config/environment', __dir__)
abort('The Rails environment is running in production mode!') if Rails.env.production?

require 'rspec/rails'
require 'capybara/rspec'

# HTML 5 validation
require 'capybara/validate_html5'

def ensure_test_assets_precompiled!
  return if ENV['SKIP_ASSET_PRECOMPILE'].present?

  assets_dir = Rails.root.join('public', 'assets')
  manifest = Dir[assets_dir.join('.sprockets-manifest*.json')].first ||
             Dir[assets_dir.join('manifest*.json')].first

  return if manifest && File.exist?(manifest)

  puts 'Precompiling assets for test environment...'
  success = system({ 'RAILS_ENV' => 'test' }, 'bin/rails', 'assets:precompile')
  abort('Assets precompile failed in test environment.') unless success
end

ActiveRecord::Migration.maintain_test_schema!

# load support files
Dir[Rails.root.join('spec', 'support', '**', '*.rb')].sort.each { |f| require f }

RSpec.configure do |config|
  config.before(:suite) do
    ensure_test_assets_precompiled!
  end

  config.before(:each) do
    Rails.cache.clear
  end

  config.include Controllers::JsonHelpers, type: :controller
  config.include Controllers::JsonHelpers, type: :request
  config.include Controllers::SessionHelpers, type: :controller

  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  # Include your helpers
  config.include Features::FormHelpers,    type: :feature
  config.include Features::FormHelpers,    type: :system
  config.include Features::SessionHelpers, type: :feature
  config.include Features::SessionHelpers, type: :system
  config.include Features::ServerHelpers,  type: :feature
  config.include Features::ServerHelpers,  type: :system
  config.include Features::GatherHelpers,  type: :feature
  config.include Features::GatherHelpers,  type: :system

  # If you also rely on JSON helpers in controller/request specs:
  config.include Controllers::JsonHelpers, type: :controller
  config.include Controllers::JsonHelpers, type: :request
end
