# frozen_string_literal: true

require 'capybara/playwright'

# HTML 5 validation
require 'capybara/validate_html5'

# Override Selenium driver to prevent LoadError when selenium-webdriver is not installed
# This prevents Capybara from trying to load Selenium during driver initialization
Capybara.register_driver :selenium do |_app|
  raise 'selenium-webdriver is not installed. Use Playwright drivers instead.'
end

# Playwright configuration
#
# Pin the Playwright CLI to the version the ruby client is compatible with.
# Without this, the driver defaults to `npx playwright`, which resolves to the
# latest Playwright and expects a browser revision that differs from the one
# installed in CI (`npx playwright@COMPATIBLE_PLAYWRIGHT_VERSION install ...`),
# causing "Executable doesn't exist at .../chromium_headless_shell-<rev>".
PLAYWRIGHT_CLI_EXECUTABLE_PATH =
  ENV.fetch('PLAYWRIGHT_CLI_EXECUTABLE_PATH', "npx playwright@#{Playwright::COMPATIBLE_PLAYWRIGHT_VERSION}")

Capybara.register_driver :playwright_chrome do |app|
  Capybara::Playwright::Driver.new(
    app,
    browser_type: :chromium,
    playwright_cli_executable_path: PLAYWRIGHT_CLI_EXECUTABLE_PATH,
    default_navigation_timeout: 120_000,
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
    playwright_cli_executable_path: PLAYWRIGHT_CLI_EXECUTABLE_PATH,
    default_navigation_timeout: 120_000,
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

# Need enough threads to serve 12 concurrent browser sessions (version polls + page loads)
# simultaneously without starving each other or the connection pool.
Capybara.server = :puma, { Silent: true, threads: '1:20' }
Capybara.default_driver = :rack_test
Capybara.javascript_driver = :playwright_chrome_headless
Capybara.default_max_wait_time = 10

RSpec.configure do |config|
  # Capybara
  config.include Capybara::DSL

  config.around(:each, type: :feature) do |example|
    # Skip per-user HTML renders in Broadcaster during feature specs.
    # N concurrent sessions each trigger O(n) partial renders on every join/vote/pick,
    # creating O(n²) render load that exhausts the DB pool under Playwright.
    # The version bump still fires so gather_sync_controller.js reloads via polling.
    Gathers::Broadcaster.skip_broadcasts = true
    example.run
  ensure
    Gathers::Broadcaster.skip_broadcasts = false
  end

  config.after(:each, type: :feature) do
    Capybara.reset_sessions!
  end
end

# print "Capybara javascript driver: #{Capybara.javascript_driver}\n"
