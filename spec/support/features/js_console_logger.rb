# Collect browser console logs after system (JS) specs and fail on errors.
RSpec.configure do |config|
  config.after(:each, type: :system) do |example|
    begin
      driver = Capybara.current_session.driver
      browser = driver.browser
      
      # Only proceed if browser exposes logs (Selenium)
      unless browser.respond_to?(:manage) && browser.manage.respond_to?(:logs)
        next
      end

      raw_logs = []
      begin
        raw_logs = browser.manage.logs.get(:browser) || []
      rescue Selenium::WebDriver::Error::UnsupportedOperationError
        raw_logs = []
      end

      next if raw_logs.empty?

      errors = raw_logs.select { |l| l.level == 'SEVERE' }
      warnings = raw_logs.select { |l| l.level == 'WARNING' }

      # Fail on errors. If JS_CONSOLE_STRICT=1 then also fail on warnings.
      strict = ENV['JS_CONSOLE_STRICT'] == '1'

      if errors.any? || (strict && warnings.any?)
        msg = "JavaScript console failures detected (#{errors.size} errors, #{warnings.size} warnings):\n"
        (errors + warnings).each do |entry|
          msg << "[#{entry.level}] #{entry.message}\n"
        end
        # Attach to RSpec failure
        raise RSpec::Expectations::ExpectationNotMetError, msg
      elsif warnings.any?
        # Print warnings to STDERR so they show up in CI logs but don't fail by default
        warn "JavaScript console warnings (non-strict):"
        warnings.each { |w| warn "[#{w.level}] #{w.message}" }
      end
    rescue => e
      warn "js_console_logger: failed to collect console logs: #{e.class}: #{e.message}"
    end
  end
end
