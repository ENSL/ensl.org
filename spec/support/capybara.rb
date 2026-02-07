require 'tmpdir'
require 'fileutils'
require 'securerandom'
require 'capybara/rspec'

# HTML 5 validation
require 'capybara/validate_html5'

ENV['CHROME_BIN'] = '/usr/lib/chromium/chromium'

# Selenium::WebDriver.logger.level = :debug
# Selenium::WebDriver.logger.output = 'tmp/test/selenium.log'

def chrome_service
  Selenium::WebDriver::Chrome::Service.new(
    log: 'tmp/test/chromedriver.log',
    args: ['--verbose']
  )
end

def build_chrome_options(headless:)
  opts = Selenium::WebDriver::Chrome::Options.new
  opts.binary = ENV['CHROME_BIN']

  profile_dir = File.join(Dir.tmpdir, "capybara-chrome-profile-#{Process.pid}-#{SecureRandom.hex(10)}")
  cache_dir   = File.join(Dir.tmpdir, "capybara-chrome-cache-#{Process.pid}-#{SecureRandom.hex(10)}")
  FileUtils.mkdir_p(profile_dir)
  FileUtils.mkdir_p(cache_dir)

  opts.add_argument("--user-data-dir=#{profile_dir}")
  opts.add_argument("--disk-cache-dir=#{cache_dir}")

  opts.add_argument('--no-sandbox')
  opts.add_argument('--disable-dev-shm-usage')
  opts.add_argument('--disable-gpu')
  opts.add_argument('--no-first-run')
  opts.add_argument('--disable-extensions')
  opts.add_argument('--no-default-browser-check')

  if headless
    opts.add_argument('--headless=new') if Gem::Version.new(Selenium::WebDriver::VERSION) >= Gem::Version.new('4.15.0')
    args = opts.args || []
    opts.add_argument('--headless') unless args.any? { |a| a.include?('headless') }
  end

  # Enable browser console logging (for test diagnostics)
  opts.add_option('goog:loggingPrefs', browser: 'ALL')
  opts
end

Capybara.register_driver :selenium_chrome do |app|
  opts = build_chrome_options(headless: false)
  if defined?(Rails) && Rails.configuration.x.respond_to?(:debug_prints) && Rails.configuration.x.debug_prints
    puts "Chrome args: #{opts.args.inspect}"
  end
  Capybara::Selenium::Driver.new(app, browser: :chrome, options: opts, service: chrome_service)
end

Capybara.register_driver :selenium_chrome_headless do |app|
  opts = build_chrome_options(headless: true)
  if defined?(Rails) && Rails.configuration.x.respond_to?(:debug_prints) && Rails.configuration.x.debug_prints
    puts "Chrome args: #{opts.args.inspect}"
  end
  Capybara::Selenium::Driver.new(app, browser: :chrome, options: opts, service: chrome_service)
end

Capybara.register_driver :selenium_headless do |app|
  Capybara::Selenium::Driver.new(app, browser: :chrome, options: build_chrome_options(headless: true))
end

Capybara.server = :puma, { Silent: true }
Capybara.default_driver = :rack_test
Capybara.javascript_driver = :selenium_chrome_headless
Capybara.default_max_wait_time = 10

RSpec.configure do |config|
  # Capybara
  config.include Capybara::DSL

  config.after(:each, type: :feature) do
    Capybara.reset_sessions!
  end
end

# print "Capybara javascript driver: #{Capybara.javascript_driver}\n"
