# Load spec_helper
require 'spec_helper'

ENV['RAILS_ENV'] ||= 'test'
require File.expand_path('../config/environment', __dir__)
abort('The Rails environment is running in production mode!') if Rails.env.production?

require 'rspec/rails'

ActiveRecord::Migration.maintain_test_schema!

# load support files
Dir[Rails.root.join('spec', 'support', '**', '*.rb')].sort.each { |f| require f }

RSpec.configure do |config|
  config.before(:each) do
    Rails.cache.clear
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
end
