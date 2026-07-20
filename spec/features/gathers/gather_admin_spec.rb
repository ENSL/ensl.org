# frozen_string_literal: true

require 'rails_helper'

RSpec.feature 'Gather admin actions', type: :feature, js: true do
  before(:all) do
    Capybara.default_max_wait_time = 5
  end

  let!(:gather) { FactoryBot.create(:gather, maps_count: 3, servers_count: 2) }
  # create a full gather: 12 players so the gather can be in PICKING state
  let!(:users) { FactoryBot.create_list(:user, 12, raw_password: 'password123') }
  let!(:gatherers) do
    users.map { |u| gather.gatherers.create!(user: u) }
  end
  let!(:replacement_user) { FactoryBot.create(:user, raw_password: 'password123') }
  let!(:admin) { FactoryBot.create(:user, :admin, raw_password: 'password123') }

  before do
    # Pre-create full gather state and sign in a single session user.
    sign_in_session_user('user_0', users.first)

    # Ensure gather is in PICKING state with captains assigned so admin actions apply
    gather.update!(status: Gather::STATE_PICKING, turn: 1)
    gather.captain1 = gather.gatherers.first
    gather.captain2 = gather.gatherers.second
    gather.save!
    gather.reload
  end

  scenario 'admin changes turn' do
    Capybara.using_session('admin') do
      sign_in_via_session(admin)
      visit edit_gather_path(gather)

      # Wait for the form to load
      expect(page).to have_selector('select#gather_turn', wait: 5)

      find('select#gather_turn').select('Team 2')

      # Click the button and wait for the page to update
      click_button 'Change Turn'

      # Wait for the redirect/update to complete
      expect(page).to have_selector('div#gather', wait: 10)

      gather.reload
      expect(gather.turn).to eq(2)
    end
  end

  scenario 'admin assigns captains' do
    Capybara.using_session('admin') do
      sign_in_via_session(admin)
      visit edit_gather_path(gather)

      # Use the last two gatherers as captains
      g_users = gather.gatherers.map { |g| g.user.username }
      last_two = g_users.last(2)
      select last_two[0], from: 'gather_captain1_id'
      select last_two[1], from: 'gather_captain2_id'
      click_button 'Restart Gather'

      # edits navigate to the new gather page; wait for it to load
      expect(page).to have_selector('div#gather')

      gather.reload
      expect(gather.status).to eq(Gather::STATE_PICKING)

      # Confirm that the selected users are now captains
      expect(page).to have_css("a[data-captain='1']", text: last_two[0])
      expect(page).to have_css("a[data-captain='2']", text: last_two[1])
    end
  end

  scenario 'admin replaces a player' do
    Capybara.using_session('admin') do
      sign_in_via_session(admin)
      visit edit_gather_path(gather)

      first_username = gather.gatherers.first.user.username
      select first_username, from: 'gatherer_id'
      fill_in 'gatherer_username', with: replacement_user.username
      click_button 'Replace Player'

      # the UI should show the replacement username when the action completes
      expect(page).to have_content(replacement_user.username)

      gather.reload
      expect(gather.users.map(&:id)).to include(replacement_user.id)
    end
  end

  scenario 'admin starts a new gather and new users can join' do
    new_gather = nil
    Capybara.using_session('admin') do
      gather_count = Gather.count

      sign_in_via_session(admin)
      visit edit_gather_path(gather)

      # submit the new gather form, wait for the flash notification, then assert DB change
      find('form.new_gather input[type=submit]').click
      expect(page).to have_selector('#notification .message', text: I18n.t('gather_create'))
      expect(Gather.count).to eq(gather_count + 1)

      new_gather = Gather.where(category: gather.category).order('id DESC').first
      expect(new_gather).not_to be_nil
    end

    joiner = FactoryBot.create(:user, raw_password: 'password123')
    sign_in_and_join_gather('joiner', joiner, new_gather)
  end
end
