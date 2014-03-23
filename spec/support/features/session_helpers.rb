module Features
  module SessionHelpers
    def sign_in
      visit root_path
      user = create(:user)
      fill_form(:user, { email: user.email, password: user.raw_password })
      click_button '»'
    end
  end
end