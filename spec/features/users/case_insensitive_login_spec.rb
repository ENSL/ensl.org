# frozen_string_literal: true

require 'rails_helper'

feature 'Case insensitive login', js: true do
  let(:username) { 'CaSe_InSeNsItIvE' }
  let(:password) { 'passwordABC123' }
  let!(:user) { create(:user, username: username, raw_password: password) }

  before do
    visit root_path
  end

  feature 'when a user with mixed-case username signs in' do
    scenario 'with a matching case allows the user to sign in' do
      fill_login_form(username)
      find('#authentication input[name="commit"]').click

      expect(page).to have_content(I18n.t('sessions.create.success'))

      within user_status do
        expect(page).to have_content(account_link)
      end
    end

    scenario 'with a non-matching case allows the user to sign in' do
      fill_login_form('CASE_INSENSITIVE')
      find('#authentication input[name="commit"]').click

      # When username case does not match, authentication is case-sensitive
      # and login should fail.
      expect(page).to have_content(I18n.t('sessions.create.failure'))
    end
  end

  def fill_login_form(username)
    fill_in 'login_username', with: username
    fill_in 'login_password', with: password
  end

  def account_link
    'ACCOUNT'
  end
end
