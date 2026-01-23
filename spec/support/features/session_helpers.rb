module Features
  module SessionHelpers
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
  end
end
