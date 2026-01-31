module Features
  module SessionHelpers
    def sign_in_via_session(user)
      session_key = Rails.application.config.session_options[:key]
      cookie_value = session_cookie_for(user, session_key)

      visit root_path
      set_session_cookie(session_key, cookie_value)
      # visit root_path
      # expected_name = /#{Regexp.escape(user.username)}/i
      # expect(page).to have_selector('#current_user', text: expected_name)
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
      visit logout_users_path
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
      find('#authentication')
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
      driver = page.driver
      return if value.nil?

      unless driver.respond_to?(:browser) && driver.browser.respond_to?(:manage)
        raise 'Current Capybara driver does not support cookie injection'
      end

      # Determine host for the cookie (selenium requires domain without port)
      require 'uri'
      host = begin
        URI.parse(page.current_url).host
      rescue StandardError
        Capybara.server_host || '127.0.0.1'
      end

      cookie = {
        name: session_key,
        value: value.to_s,
        path: '/',
        domain: host,
        secure: false,
        httpOnly: false
      }

      begin
        driver.browser.manage.add_cookie(cookie)
      rescue Selenium::WebDriver::Error::InvalidCookieDomainError
        # Fallback: try without domain
        driver.browser.manage.add_cookie(name: session_key, value: value.to_s, path: '/')
      end
    end
  end
end
