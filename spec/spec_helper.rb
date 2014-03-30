ENV["RAILS_ENV"] ||= 'test'

require 'codeclimate-test-reporter'
require 'simplecov'
CodeClimate::TestReporter.start
SimpleCov.start 'rails'

require File.expand_path("../../config/environment", __FILE__)
require 'rspec/rails'
require 'capybara/rspec'
require 'capybara/poltergeist'

Capybara.register_driver :poltergeist do |app|
  Capybara::Poltergeist::Driver.new(app, :phantomjs_logger => File.open('/dev/null'))
end

Capybara.javascript_driver = :poltergeist

Dir[Rails.root.join("spec/support/**/*.rb")].each { |f| require f }

RSpec.configure do |config|
  config.include FactoryGirl::Syntax::Methods
  config.include Controllers::JsonHelpers, type: :controller
  config.include Features::FormHelpers, type: :feature
  config.include Features::SessionHelpers, type: :feature

  config.fixture_path = "#{::Rails.root}/spec/fixtures"
  config.order = 'random'
  config.use_transactional_fixtures = false

  config.before(:each) do
    if example.metadata[:type] == :feature
      Capybara.current_driver = :poltergeist
    else
      Capybara.use_default_driver
    end
  end
end
