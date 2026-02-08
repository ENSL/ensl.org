require 'capybara/playwright'

# HTML 5 validation
require 'capybara/validate_html5'

# Override Selenium driver to prevent LoadError when selenium-webdriver is not installed
# This prevents Capybara from trying to load Selenium during driver initialization
Capybara.register_driver :selenium do |app|
  raise 'selenium-webdriver is not installed. Use Playwright drivers instead.'
end

# Playwright configuration
Capybara.register_driver :playwright_chrome do |app|
  Capybara::Playwright::Driver.new(
    app,
    browser_type: :chromium,
    headless: false,
    screen: { width: 1280, height: 1024 },
    browser_options: {
      args: [
        '--no-sandbox',
        '--disable-dev-shm-usage',
        '--disable-gpu'
      ]
    }
  )
end

Capybara.register_driver :playwright_chrome_headless do |app|
  Capybara::Playwright::Driver.new(
    app,
    browser_type: :chromium,
    headless: true,
    screen: { width: 1280, height: 1024 },
    browser_options: {
      args: [
        '--no-sandbox',
        '--disable-dev-shm-usage',
        '--disable-gpu'
      ]
    }
  )
end

Capybara.server = :puma, { Silent: true }
Capybara.default_driver = :rack_test
Capybara.javascript_driver = :playwright_chrome_headless
Capybara.default_max_wait_time = 10

RSpec.configure do |config|
  # Capybara
  config.include Capybara::DSL

  config.after(:each, type: :feature) do
    Capybara.reset_sessions!
  end
end

# print "Capybara javascript driver: #{Capybara.javascript_driver}\n"
