# frozen_string_literal: true

require 'rails_helper'

RSpec.feature 'Gather header badge', type: :feature do
  let!(:category) { create(:category, :game, name: 'NS2') }
  let!(:gather) { create(:gather, category: category) }
  let!(:user) { create(:user) }

  scenario 'shows the picking badge while a pick slot is still open' do
    create(:gatherer, gather: gather, user: user, team: 1)
    create(:gatherer, gather: gather, team: 2)
    gather.update_columns(status: Gather::STATE_PICKING, turn: 1)

    sign_in_as(user)
    visit root_path

    expect(page).to have_content('Captains are picking teams')
  end

  scenario 'shows the finished badge once both teams are full, even before the status column flips' do
    create(:gatherer, gather: gather, user: user, team: 1)
    create_list(:gatherer, 5, gather: gather, team: 1)
    create_list(:gatherer, 6, gather: gather, team: 2)
    gather.update_columns(status: Gather::STATE_PICKING, turn: 2)

    sign_in_as(user)
    visit root_path

    expect(page).to have_content("You've signed up for NS2 Gather.")
    expect(page).to have_content('Just finished, check the results')
    expect(page).not_to have_content('Captains are picking teams')
  end

  scenario 'still shows the recently finished gather even though an empty follow-up gather already exists' do
    create(:gatherer, gather: gather, user: user)
    gather.update_column(:status, Gather::STATE_FINISHED)
    create(:gather, category: category) # empty follow-up, auto-created when voting ended

    sign_in_as(user)
    visit root_path

    expect(page).to have_content("You've signed up for NS2 Gather.")
  end

  scenario 'hides the badge once players have actually started joining the newer gather' do
    create(:gatherer, gather: gather, user: user)
    gather.update_column(:status, Gather::STATE_FINISHED)
    newer_gather = create(:gather, category: category)
    create(:gatherer, gather: newer_gather)

    sign_in_as(user)
    visit root_path

    expect(page).not_to have_content("You've signed up for NS2 Gather.")
  end

  scenario 'hides the badge while viewing the gather page itself' do
    create(:gatherer, gather: gather, user: user)
    gather.update_column(:status, Gather::STATE_RUNNING)

    sign_in_as(user)
    visit gather_path(gather)

    expect(page).not_to have_content("You've signed up for NS2 Gather.")
  end

  scenario 'shows the signed-up link after really joining via the UI, hidden on the gather page itself',
           js: true do
    join_category = create(:category, :game, name: 'NS1')
    join_gather = create(:gather, category: join_category, maps_count: 3, servers_count: 2)
    joiner = create(:user, raw_password: 'password123')

    sign_in_and_join_gather('member', joiner, join_gather)

    Capybara.using_session('member') do
      visit root_path
      expect(page).to have_link("You've signed up for NS1 Gather.", wait: 5)

      visit gather_path(join_gather)
      expect(page).not_to have_link("You've signed up for NS1 Gather.")
    end
  end
end
