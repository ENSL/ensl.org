ENV["RAILS_ENV"] ||= 'test'

require 'codeclimate-test-reporter'
require 'simplecov'
CodeClimate::TestReporter.start
SimpleCov.start 'rails'

require File.expand_path("../../config/environment", __FILE__)
require 'rspec/rails'
require 'capybara/rspec'
require 'capybara/poltergeist'

Capybara.default_wait_time = 30
Capybara.register_driver :poltergeist do |app|
  Capybara::Poltergeist::Driver.new(app,
    timeout: 30,
    phantomjs_logger: File.open('/dev/null')
  )
end

Capybara.javascript_driver = :poltergeist

Dir[Rails.root.join("spec/support/**/*.rb")].each { |f| require f }

RSpec.configure do |config|
  config.include FactoryGirl::Syntax::Methods
  config.include Controllers::JsonHelpers, type: :controller
  config.include Features::FormHelpers, type: :feature
  config.include Features::ServerHelpers, type: :feature
  config.include Features::SessionHelpers, type: :feature

  config.fixture_path = "#{::Rails.root}/spec/fixtures"
  config.order = 'random'
  config.use_transactional_fixtures = false
  config.color = true
  config.formatter = :documentation

  config.before(:each) do
    events_list_json = JSON.parse(File.read(Rails.root.join('spec/fixtures/google_calendar.json')))

    GoogleCalendar::Request.stub(:events_list) do
      GoogleCalendar::EventList.new(events_list_json, Time.zone.name)
    end
  end
end
