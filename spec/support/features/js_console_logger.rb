# frozen_string_literal: true

# Collect browser console logs after feature and system specs and fail on errors.
module Features
  module JsConsoleLogger
    module_function

    def prepare_playwright_console_listener
      return unless Capybara.current_driver.to_s.include?('playwright')

      driver = Capybara.current_session.driver
      return unless driver.is_a?(Capybara::Playwright::Driver)

      Thread.current[:playwright_console_logs] = []
      Thread.current[:playwright_console_listener_needed] = true
    rescue StandardError => e
      warn "js_console_logger: failed to prepare Playwright console listener: #{e.class}: #{e.message}"
    end

    def collect_playwright_console_logs
      driver = Capybara.current_session.driver
      return unless driver.is_a?(Capybara::Playwright::Driver)

      if Thread.current[:playwright_console_listener_needed]
        begin
          driver.current_url
          browser_wrapper = driver.instance_variable_get(:@browser)
          playwright_page = browser_wrapper&.instance_variable_get(:@playwright_page)

          if playwright_page
            Thread.current[:playwright_console_logs] ||= []
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

      return if logs.empty?

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
    rescue StandardError => e
      warn "js_console_logger: failed to collect console logs: #{e.class}: #{e.message}"
    end

    def collect_legacy_browser_logs
      driver = Capybara.current_session.driver
      return unless driver.respond_to?(:browser)

      browser = driver.browser
      return unless browser.respond_to?(:manage) && browser.manage.respond_to?(:logs)

      raw_logs = browser.manage.logs.get(:browser) || []
      return if raw_logs.empty?

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
    rescue StandardError => e
      warn "js_console_logger: failed to collect console logs: #{e.class}: #{e.message}"
    end
  end
end

RSpec.configure do |config|
  config.before(:each, type: %i[feature system]) do
    Features::JsConsoleLogger.prepare_playwright_console_listener
  end

  config.after(:each, type: %i[feature system]) do
    Features::JsConsoleLogger.collect_playwright_console_logs
    Features::JsConsoleLogger.collect_legacy_browser_logs
  end
end
