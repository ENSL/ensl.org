# frozen_string_literal: true

require 'rails_helper'

RSpec.feature 'Passkey authentication', type: :feature, js: true do
  let(:password) { 'PasswordABC123!' }
  let(:passkey_user) { create(:user, username: 'passkey_user', raw_password: password) }

  scenario 'the login form exposes passkey sign-in for browsers that support it' do
    visit root_path

    expect(page).to have_button('Use passkey')
  end

  scenario 'password login on a passkey-enabled account sends an email OTP and then logs in' do
    passkey_user.passkey_credentials.create!(external_id: 'credential-1', public_key: 'public-key', sign_count: 0)
    ActionMailer::Base.deliveries.clear

    visit root_path
    fill_in 'login_username', with: passkey_user.username
    fill_in 'login_password', with: password

    expect(ActionMailer::Base.deliveries).to be_empty

    submit_login_form

    expect(page).to have_field('login_otp_code', wait: 10)
    expect(ActionMailer::Base.deliveries.size).to eq(1)

    otp_code = ActionMailer::Base.deliveries.last.body.to_s[/\b\d{6}\b/]
    expect(otp_code).to be_present

    fill_in 'login_otp_code', with: otp_code
    submit_login_form

    expect(page).to have_content('LOGOUT', wait: 10)
  end

  private

  def submit_login_form
    page.execute_script("document.querySelector(\"form[action='/users/login']\").requestSubmit()")
  end
end
