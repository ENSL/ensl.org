module Features
  module SessionHelpers
    def sign_in_as(user)      
      visit root_path

      fill_in "login_username", with: user.username
      fill_in "login_password", with: user.raw_password

      click_button I18n.t('helpers.submit.user.login')
    end

    def change_timezone_for(user, timezone)
      visit edit_user_path(user.id)

      click_link I18n.t('profile.locals')
      find("option[value='#{timezone}']").select_option
      
      click_button I18n.t('helpers.submit.user.update')
    end
  end
end