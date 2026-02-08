require 'fileutils'

RSpec.configure do |config|
  config.after(:each, type: :feature) do |example|
    next unless example.exception

    # Only attempt to save failure artifacts if a driver is available
    unless Capybara.current_driver && Capybara.current_driver != Capybara.default_driver
      next
    end

    failures_dir = Rails.root.join('tmp', 'rspec_failures')
    FileUtils.mkdir_p(failures_dir)

    name = example.full_description.gsub(/[^\w\-]+/, '_')[0, 200]
    timestamp = Time.now.utc.strftime('%Y%m%d-%H%M%S')
    base = failures_dir.join("#{timestamp}-#{name}")

    # Save HTML
    begin
      if defined?(page) && page.respond_to?(:html)
        File.open(base.to_s + '.html', 'wb') { |f| f.write(page.html) }
      end
    rescue StandardError => e
      File.open(base.to_s + '.html_error.txt', 'w') { |f| f.write(e.message) }
    end

    # Save screenshot
    begin
      if defined?(page) && page.respond_to?(:save_screenshot)
        page.save_screenshot(base.to_s + '.png', full: true)
      elsif defined?(Capybara) && Capybara.respond_to?(:save_screenshot)
        Capybara.save_screenshot(base.to_s + '.png')
      end
    rescue StandardError => e
      File.open(base.to_s + '.screenshot_error.txt', 'w') { |f| f.write(e.message + "\n" + e.backtrace.join("\n")) }
    end

    # Save current URL
    begin
      if defined?(page) && page.respond_to?(:current_url)
        File.open(base.to_s + '.url.txt', 'w') { |f| f.write(page.current_url.to_s) }
      end
    rescue StandardError
    end

    # Save browser console logs (if available)
    begin
      if defined?(page) && page.driver.respond_to?(:browser)
        browser = page.driver.browser
        if browser.respond_to?(:manage) && browser.manage.respond_to?(:logs)
          logs = browser.manage.logs.get(:browser)
          unless logs.empty?
            File.open(base.to_s + '.console.log', 'w') do |f|
              logs.each { |l| f.puts("[#{l.level}] #{l.message}") }
            end
          end
        end
      end
    rescue StandardError => e
      File.open(base.to_s + '.console_error.log', 'w') { |f| f.write(e.message) }
    end

    # Save tail of test.log
    begin
      test_log = Rails.root.join('log', 'test.log')
      if File.exist?(test_log)
        lines = File.readlines(test_log).last(500) || []
        File.open(base.to_s + '.test.log', 'w') { |f| f.puts(lines) }
      end
    rescue StandardError
    end
  end

  # config.after(:each, type: :system) do |example|
  #   RSpec.configuration.hooks_for_example_group(:after).each do |hook|
  #   end
  # end
end

