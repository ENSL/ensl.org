# frozen_string_literal: true

# Collect browser console logs after system (JS) specs and fail on errors.
RSpec.configure do |config|
  # Set up console listener for Playwright before each test
  config.before(:each, type: :system) do
    next unless Capybara.current_driver.to_s.include?('playwright')

    begin
      driver = Capybara.current_session.driver
      next unless driver.is_a?(Capybara::Playwright::Driver)

      # Initialize thread-safe storage for console messages
      Thread.current[:playwright_console_logs] = []

      # The page might not be created yet, so we'll set up the listener later
      # Store a flag to set it up on first page access
      Thread.current[:playwright_console_listener_needed] = true
    rescue StandardError => e
      warn "js_console_logger: failed to prepare Playwright console listener: #{e.class}: #{e.message}"
    end
  end

  config.after(:each, type: :system) do |_example|
    driver = Capybara.current_session.driver

    # Handle Playwright driver
    if driver.is_a?(Capybara::Playwright::Driver)
      # Ensure console listener is set up
      if Thread.current[:playwright_console_listener_needed]
        begin
          driver.current_url # Ensure page is initialized
          browser_wrapper = driver.instance_variable_get(:@browser)
          playwright_page = browser_wrapper&.instance_variable_get(:@playwright_page)

          if playwright_page
            Thread.current[:playwright_console_logs] ||= []

            # Set up console message listener
            playwright_page.on('console', lambda { |msg|
              Thread.current[:playwright_console_logs] << {
                type: msg.type,
                text: msg.text,
                args: msg.args
              }
            })

            Thread.current[:playwright_console_listener_needed] = false
          end
        rescue StandardError => e
          warn "js_console_logger: failed to set up Playwright listener: #{e.class}: #{e.message}"
        end
      end

      logs = Thread.current[:playwright_console_logs] || []
      Thread.current[:playwright_console_logs] = nil
      Thread.current[:playwright_console_listener_needed] = nil

      next if logs.empty?

      # Map Playwright console types to severity
      errors = logs.select { |l| l[:type] == 'error' }
      warnings = logs.select { |l| l[:type] == 'warning' }

      strict = ENV['JS_CONSOLE_STRICT'] == '1'

      if errors.any? || (strict && warnings.any?)
        msg = "JavaScript console failures detected (#{errors.size} errors, #{warnings.size} warnings):\n"
        (errors + warnings).each do |entry|
          msg << "[#{entry[:type].upcase}] #{entry[:text]}\n"
        end
        raise RSpec::Expectations::ExpectationNotMetError, msg
      elsif warnings.any?
        warn 'JavaScript console warnings (non-strict):'
        warnings.each { |w| warn "[#{w[:type].upcase}] #{w[:text]}" }
      end

    # Handle Selenium driver (legacy support)
    elsif driver.respond_to?(:browser)
      browser = driver.browser

      # Only proceed if browser exposes logs
      next unless browser.respond_to?(:manage) && browser.manage.respond_to?(:logs)

      raw_logs = []
      begin
        raw_logs = browser.manage.logs.get(:browser) || []
      rescue StandardError
        raw_logs = []
      end

      next if raw_logs.empty?

      errors = raw_logs.select { |l| l.level == 'SEVERE' }
      warnings = raw_logs.select { |l| l.level == 'WARNING' }

      strict = ENV['JS_CONSOLE_STRICT'] == '1'

      if errors.any? || (strict && warnings.any?)
        msg = "JavaScript console failures detected (#{errors.size} errors, #{warnings.size} warnings):\n"
        (errors + warnings).each do |entry|
          msg << "[#{entry.level}] #{entry.message}\n"
        end
        raise RSpec::Expectations::ExpectationNotMetError, msg
      elsif warnings.any?
        warn 'JavaScript console warnings (non-strict):'
        warnings.each { |w| warn "[#{w.level}] #{w.message}" }
      end
    end
  rescue StandardError => e
    warn "js_console_logger: failed to collect console logs: #{e.class}: #{e.message}"
  end
end
