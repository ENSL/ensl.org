module Features
  module SessionHelpers
    def sign_in_as(user)
      visit root_path

      find_field("login_username").set(user.username)
      fill_in "login_password", with: user.raw_password

      # Apparently poltergeist does not suppor this
      find('#authentication input[name="commit"]').click()
      # click_button I18n.t("helpers.submit.user.login")

      expect(page).to have_content(I18n.t('login_successful'))
    end

    def sign_out
      visit root_path
      
      find('a#logout').trigger('click')
      expect(page).to have_content(I18n.t('login_out'))
    end

    def change_timezone_for(user, timezone)
      visit edit_user_path(user.id)

      click_link I18n.t("profile.locals")
      find("option[value='#{timezone}']").select_option
      
      click_button I18n.t("helpers.submit.user.update")
    end

    def user_status
      find "#authentication"
    end

    def registration_form
      find "#new_user"
    end
  end
end
