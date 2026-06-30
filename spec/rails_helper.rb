# frozen_string_literal: true

# Load spec_helper
require 'spec_helper'
require 'fileutils'
require 'tmpdir'

ENV['RAILS_ENV'] ||= 'test'
require File.expand_path('../config/environment', __dir__)
abort('The Rails environment is running in production mode!') if Rails.env.production?

# CI can inject FILES_ROOT values that are not writable by the test process.
# Force a test-local writable root for all specs unless a spec overrides it.
ENV['FILES_ROOT'] = File.join(Dir.tmpdir, 'ensl_test_files')
FileUtils.mkdir_p(ENV.fetch('FILES_ROOT'))

require 'rspec/rails'
require 'capybara/rspec'

ActiveRecord::Migration.maintain_test_schema!

# load support files
Dir[Rails.root.join('spec/support/**/*.rb')].sort.each { |f| require f }

RSpec.configure do |config|
  config.before(:suite) do
    FileUtils.rm_rf(ENV.fetch('FILES_ROOT'))
    FileUtils.mkdir_p(ENV.fetch('FILES_ROOT'))

    log_file = Rails.root.join('log/test.log')
    FileUtils.mkdir_p(log_file.dirname)
    File.write(log_file, '')
  end

  config.before(:each) do
    Rails.cache.clear
  end

  config.around(:each, type: :feature) do |example|
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    example.run
  ensure
    ActionController::Base.allow_forgery_protection = original
  end

  config.around(:each, type: :system) do |example|
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    example.run
  ensure
    ActionController::Base.allow_forgery_protection = original
  end

  config.filter_rails_from_backtrace!

  config.include Controllers::JsonHelpers, type: :controller
  config.include Controllers::JsonHelpers, type: :request
  config.include Controllers::SessionHelpers, type: :controller

  config.include Features::FormHelpers,    type: :feature
  config.include Features::FormHelpers,    type: :system
  config.include Features::SessionHelpers, type: :feature
  config.include Features::SessionHelpers, type: :system
  config.include Features::ServerHelpers,  type: :feature
  config.include Features::ServerHelpers,  type: :system
  config.include Features::GatherHelpers,  type: :feature
  config.include Features::GatherHelpers,  type: :system
  config.include Features::ContestsHelpers, type: :feature
  config.include Features::ContestsHelpers, type: :system
end
