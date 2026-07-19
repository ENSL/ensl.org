# frozen_string_literal: true

require 'cgi'

module Features
  module SessionHelpers
    def sign_in_via_session(user)
      session_key = Rails.application.config.session_options[:key]
      cookie_value = session_cookie_for(user, session_key)

      visit root_path # This creates the playwright_page
      set_session_cookie(session_key, cookie_value)
      visit root_path

      expected_name = /#{Regexp.escape(user.username)}/i
      return if page.has_selector?('#current_user', text: expected_name, visible: :all, wait: 4)

      # Fallback for rare Playwright cookie propagation races in multi-session specs.
      sign_in_as(user)
      visit root_path
      expect(page).to have_selector('#current_user', text: expected_name, visible: :all)
    end

    def sign_in_as(user)
      visit root_path

      find_field('login_username').set(user.username)
      fill_in 'login_password', with: user.raw_password

      # Apparently poltergeist does not suppor this
      find('#authentication input[name="commit"]').click
      # click_button I18n.t("helpers.submit.user.login")

      expect(page).to have_content(I18n.t('login_successful'))
    end

    def sign_out
      visit root_path

      # The logout link is implemented as a JS-backed form submit in the UI.
      # In test drivers without JS the click won't submit — navigate to the
      # logout path directly which is available as a GET for compatibility.
      visit logout_sessions_path
      # Expect either the flash or the login link to confirm logout succeeded
      expect(page).to(have_content(I18n.t('login_out')).or(have_content(I18n.t('helpers.submit.user.login'))))
    end

    def change_timezone_for(user, timezone)
      visit edit_user_path(user.id)

      click_link I18n.t('profile.locals')
      find("option[value='#{timezone}']").select_option

      click_button I18n.t('helpers.submit.user.update')
    end

    def user_status
      '#authentication'
    end

    def registration_form
      '#new_user'
    end

    private

    def session_cookie_for(user, session_key)
      env = Rails.application.env_config.merge(Rack::MockRequest.env_for('/'))
      request = ActionDispatch::Request.new(env)

      store = ActionDispatch::Session::CookieStore.new(
        ->(_env) { [200, {}, []] },
        Rails.application.config.session_options
      )

      session = ActionDispatch::Request::Session.create(
        store,
        request,
        Rails.application.config.session_options
      )
      session[:user] = user.id

      response = ActionDispatch::Response.new
      store.send(:commit_session, request, response)

      set_cookies = request.cookie_jar.instance_variable_get(:@set_cookies) || {}
      raw = set_cookies[session_key]
      raw = raw[:value] if raw.is_a?(Hash)
      raw.to_s
    end

    def set_session_cookie(session_key, value)
      return if value.nil?

      driver = page.driver

      # Determine host and URL for the cookie
      require 'uri'
      current_uri = begin
        URI.parse(page.current_url)
      rescue StandardError
        URI.parse("http://#{Capybara.server_host || '127.0.0.1'}:#{Capybara.server_port || 3000}")
      end

      host = current_uri.host || '127.0.0.1'

      # Handle different driver types
      if driver.is_a?(Capybara::Playwright::Driver)
        # The driver has a @browser which wraps Playwright and has @playwright_page
        # Access it via send since browser is a private method, or trigger it by calling a public method
        driver.current_url # This ensures browser is initialized

        # Now access the internal browser wrapper
        browser_wrapper = driver.instance_variable_get(:@browser)
        playwright_page = browser_wrapper.instance_variable_get(:@playwright_page)

        raise 'Playwright page not initialized. This should not happen after visiting a page.' if playwright_page.nil?

        # Construct the base URL for the cookie - use the actual current URL
        current_page_url = playwright_page.url

        # Use the actual page URL for the cookie
        # Playwright expects string keys, not symbols
        playwright_cookie = {
          'name' => session_key,
          'value' => value.to_s,
          'url' => current_page_url,
          'sameSite' => 'Lax'
        }

        # Clear only the session cookie to avoid conflicts, keep other cookies
        playwright_page.context.clear_cookies(name: session_key)

        # Add cookie via the page's browser context
        playwright_page.context.add_cookies([playwright_cookie])

        # Verify the cookie was added
        added_cookies = playwright_page.context.cookies
        added_cookie = added_cookies.find { |c| c['name'] == session_key }
        raise 'Failed to add session cookie - no cookies found after add_cookies' unless added_cookie
      elsif driver.respond_to?(:browser) && driver.browser.respond_to?(:manage)
        # Selenium API
        cookie = {
          name: session_key,
          value: value.to_s,
          path: '/',
          secure: false,
          httpOnly: false
        }
        # Add domain only for non-localhost
        cookie[:domain] = host unless host == '127.0.0.1'

        begin
          driver.browser.manage.add_cookie(cookie)
        rescue Selenium::WebDriver::Error::InvalidCookieDomainError
          # Fallback: try without domain
          driver.browser.manage.add_cookie(name: session_key, value: value.to_s, path: '/')
        end
      else
        raise 'Current Capybara driver does not support cookie injection'
      end
    end
  end
end
