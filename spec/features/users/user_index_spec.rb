# frozen_string_literal: true

require 'rails_helper'

RSpec.feature 'User index', type: :feature do
  scenario 'searches users by username' do
    matching_user = create(:user, username: 'SearchablePlayer')
    create(:user, username: 'AnotherPlayer')

    visit users_path
    fill_in 'search', with: 'searchable'
    click_button 'Search'

    expect(page).to have_current_path(users_path, ignore_query: true)
    expect(page.current_url).to include('search=searchable')
    within '#users' do
      expect(page).to have_link(matching_user.username, href: user_path(matching_user))
      expect(page).not_to have_content('AnotherPlayer')
    end
  end

  scenario 'paginates users forty at a time' do
    create_list(:user, 41)

    visit users_path

    expect(page).to have_css('#users tr', count: 41)
    expect(page).to have_link('2', href: users_path(page: 2))

    find(:link, '2', href: users_path(page: 2), match: :first).click

    expect(page).to have_current_path(users_path(page: 2), ignore_query: false)
    expect(page).to have_css('#users tr', count: 2)
  end

  scenario 'shows recently active users without preserving unrelated listing parameters' do
    recent_user = create(:user, username: 'RecentUser', lastvisit: 1.day.ago)
    create(:user, username: 'StaleUser', lastvisit: 6.months.ago)

    visit users_path(search: 'StaleUser', sort: 'username', direction: 'desc')

    expect(page).to have_link('Show them', href: users_path(filter: 'lately'))

    click_link 'Show them'

    expect(page).to have_current_path(users_path(filter: 'lately'), ignore_query: false)
    expect(page).to have_content(recent_user.username)
    expect(page).not_to have_content('StaleUser')
  end
end
