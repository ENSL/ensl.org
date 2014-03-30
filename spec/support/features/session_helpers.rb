module Features
  module SessionHelpers
    def sign_in_as(user)      
      visit root_path

      fill_in "login_username", with: user.username
      fill_in "login_password", with: user.raw_password

      click_button 'Login'
    end
  end
end