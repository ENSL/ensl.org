# frozen_string_literal: true

module Features
  module SafeClick
    # A helper method to safely click on elements.
    # Exists because dynamic pages can be missing elements momentarily
    # Usage:
    # safe_click('css selector', match: :first)
    # safe_click { find('ul#map-votes').all('a').sample.click }

    def safe_click(selector = nil, **find_opts)
      attempts = 0
      begin
        if block_given?
          yield
        else
          find(selector, **find_opts).click
        end
      rescue Capybara::Playwright::Node::NotActionableError, Capybara::Playwright::Node::StaleReferenceError,
             Playwright::Error
        # Playwright-specific errors for stale or non-actionable elements
        attempts += 1
        raise if attempts > 8

        sleep(0.1)
        retry
      rescue Capybara::ElementNotFound, NoMethodError
        attempts += 1
        raise if attempts > 8

        sleep(0.1)
        retry
      end
    end

    # Expect page to contain text with retries on transient stale-node errors
    def safe_expect_text(text, wait: Capybara.default_max_wait_time)
      attempts = 0
      begin
        expect(page).to have_content(text, wait: wait)
      rescue Capybara::Playwright::Node::NotActionableError, Capybara::Playwright::Node::StaleReferenceError
        # Playwright-specific errors for stale or non-actionable elements
        attempts += 1
        raise if attempts > 8

        sleep(0.1)
        retry
      rescue Capybara::ElementNotFound
        attempts += 1
        raise if attempts > 8

        sleep(0.1)
        retry
      end
    end

    def safe_has_selector?(selector, wait: Capybara.default_max_wait_time, **options)
      attempts = 0
      begin
        page.has_selector?(selector, wait: wait, **options)
      rescue Capybara::Playwright::Node::NotActionableError, Capybara::Playwright::Node::StaleReferenceError,
             Playwright::Error
        attempts += 1
        return false if attempts > 3

        sleep(0.1)
        retry
      rescue Capybara::ElementNotFound
        attempts += 1
        return false if attempts > 3

        sleep(0.1)
        retry
      end
    end
  end
end

RSpec.configure do |c|
  c.include Features::SafeClick, type: :feature
end
