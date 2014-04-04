require 'spec_helper'

feature 'Case insensitive login' do
  let(:username) { "CaSe_InSeNsItIvE" }
  let(:password) { "passwordABC123" }
  let!(:user) { create(:user, username: username, raw_password: password) }

  before do
    visit root_path
  end

  feature 'when a user with mixed-case username signs in' do
    scenario 'with a matching case allows the user to sign in' do
      fill_login_form(username)
      click_button submit(:user, :login)
      
      expect(page).to have_content(I18n.t('login_successful'))
      expect(page).to have_content("Logged in as: #{username}")
    end

    scenario 'with a non-matching case allows the user to sign in' do
      fill_login_form("CASE_INSENSITIVE")
      click_button submit(:user, :login)
      
      expect(page).to have_content(I18n.t('login_successful'))
      expect(page).to have_content("Logged in as: #{username}")
    end
  end

  def fill_login_form(username)
    fill_in "login_username", with: username
    fill_in "login_password", with: password
  end
end
