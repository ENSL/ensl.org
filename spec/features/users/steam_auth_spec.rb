# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Steam authentication link', type: :feature, js: true do
  it 'renders a steam-login anchor and a hidden steam form' do
    visit root_path

    expect(page).to have_selector('a.steam-login')
    expect(page).to have_selector('form#steam-auth-form[style*="display:none"]', visible: false)
  end

  it 'user creates a new account via Steam', js: true do
    username = 'spec_steam_user'
    email = 'spec+steam@example.com'
    OmniAuth.config.mock_auth[:steam] = OmniAuth::AuthHash.new(
      provider: 'steam',
      uid: '76561198000000000',
      info: {
        nickname: username,
        name: 'Steam User',
        urls: { Profile: 'https://steamcommunity.com/id/spec_steam_user/' }
      },
      extra: { raw_info: { loccountrycode: 'FI' } }
    )

    visit root_path

    # Verify the steam login components exist
    expect(page).to have_selector('a.steam-login')
    expect(page).to have_selector('form#steam-auth-form[style*="display:none"]', visible: false)

    # click the steam image inside the link so Capybara can interact reliably
    find('a.steam-login img').click

    # Wait for the page to navigate/load after form submission
    # The form submission triggers OmniAuth which in test mode immediately calls the callback
    expect(page).to have_content('Registration', wait: 10)

    within('form#new_user') do
      username_field = find('input#user_username')
      username_field.send_keys([:control, 'a'], :backspace)
      username_field.send_keys(username)

      email_field = find('input#user_email')
      email_field.send_keys([:control, 'a'], :backspace)
      email_field.send_keys(email)

      # SteamID should be prefilled in the input after Steam auth
      steamid = find('input#user_steamid').value
      expect(steamid).to eq(User.normalize_steamid('76561198000000000'))

      select '1990', from: 'user_birthdate_1i'
      select 'January', from: 'user_birthdate_2i'
      select '1', from: 'user_birthdate_3i'

      click_button 'Register'
    end

    # After signup, user should be logged in
    expect(page).to have_link('Logout')
    expect(page).to have_content(username)

    created_user = User.find_by!(username: username)
    expect(created_user.country).to eq('FI')
    expect(created_user.profile.steam_profile).to eq('spec_steam_user')
  end
end
