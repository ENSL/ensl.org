# frozen_string_literal: true

require 'rails_helper'

feature 'Bans management', :js do
  let!(:ban)   { create :ban }
  let!(:admin) { create :user, :admin }
  let!(:user)  { create :user }

  background do
    # ensure the created ban's user exists and can be signed in if needed
    ban
  end

  before(:all) do
    Capybara.default_max_wait_time = 5
  end

  scenario 'Index lists bans and show displays details' do
    sign_in_as user
    visit bans_path

    expect(page).to have_text('Active Bans')
    expect(page).to have_text(ban.user.username)

    click_link ban.user.username
    expect(page).to have_text("Ban: #{ban.user}")
    expect(page).to have_text(ban.reason)
  end

  scenario 'Non-admin cannot access new ban' do
    sign_in_as user
    visit new_ban_path

    expect(page).to have_text('You are not allowed to visit the page you were looking for.')
  end

  # Admi can create a ban
  scenario 'Admin can create a ban' do
    sign_in_as admin
    visit new_ban_path

    fill_in 'ban_user_name', with: user.username
    fill_in 'Reason', with: 'Violation of rules'
    click_button 'Create'

    expect(page).to have_text('Ban was successfully created.')
    expect(page).to have_text("Ban: #{user.username}")
    expect(page).to have_text('Violation of rules')
  end

  scenario 'Admin sees error for unknown username' do
    sign_in_as admin
    visit new_ban_path

    fill_in 'ban_user_name', with: 'this_user_does_not_exist_123'
    fill_in 'Reason', with: 'Some reason'
    click_button 'Create'

    expect(page).to have_text('User not found')
    expect(page).to have_text('New Ban')
  end

  # Admin sees error for empty username for non-server ban
  scenario 'Admin sees error for empty username for non-server ban' do
    sign_in_as admin
    visit new_ban_path
    select 'Website Logon', from: 'ban_ban_type'
    fill_in 'Reason', with: 'Some reason'
    click_button 'Create'
    expect(page).to have_text('User or server must be specified for this ban type')
    expect(page).to have_text('New Ban')
  end

  scenario 'Admin can edit a ban' do
    ban.update(creator: admin)

    sign_in_as admin
    visit edit_ban_path(ban)
    expect(page).to have_text('Editing Ban')

    # Check the username is pre-filled
    expect(find_field('ban_user_name').value).to eq(ban.user.username)

    fill_in 'Reason', with: 'Updated reason'
    click_button 'Update'
    expect(page).to have_text('Ban was successfully updated.')
    expect(page).to have_text('Updated reason')
  end

  scenario 'Non-admin cannot edit a ban they did not create' do
    sign_in_as user
    visit edit_ban_path(ban)

    expect(page).to have_text('You are not allowed to visit the page you were looking for.')
  end
end
