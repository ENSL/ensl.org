# frozen_string_literal: true

require 'rails_helper'

RSpec.feature 'Gather admin actions', type: :feature, js: true do
  before(:all) do
    Capybara.default_max_wait_time = 5
  end

  let!(:gather) { FactoryBot.create(:gather, maps_count: 4, servers_count: 2) }
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

  scenario 'other players see admin map and server changes without reloading' do
    original_maps = gather.gather_maps.first(2)
    selected_maps = gather.gather_maps.last(2)
    original_server = gather.servers.first
    selected_server = gather.servers.last
    gather.update!(status: Gather::STATE_FINISHED, map1: original_maps.first, map2: original_maps.second,
                   server: original_server)

    Capybara.using_session('observer') do
      sign_in_via_session(users.first)
      visit gather_path(gather)
      expect(page).to have_content(original_maps.first.to_s)
      expect(page).to have_content(original_maps.second.to_s)
      expect(page).to have_content(original_server.to_s)
      expect(page).to have_no_content(selected_maps.first.to_s)
      expect(page).to have_no_content(selected_maps.second.to_s)
      expect(page).to have_no_content(selected_server.to_s)
    end

    Capybara.using_session('admin') do
      sign_in_via_session(admin)
      visit edit_gather_path(gather)

      select selected_maps.first.to_s, from: 'gather_map1_id'
      select selected_maps.second.to_s, from: 'gather_map2_id'
      select selected_server.to_s, from: 'gather_server_id'
      click_button 'Change Maps and Server'

      expect(page).to have_selector('div#gather', wait: 10)
    end

    gather.reload
    expect(gather.map1).to eq(selected_maps.first)
    expect(gather.map2).to eq(selected_maps.second)
    expect(gather.server).to eq(selected_server)

    Capybara.using_session('observer') do
      expect(page).to have_content(selected_maps.first.to_s, wait: 10)
      expect(page).to have_content(selected_maps.second.to_s)
      expect(page).to have_content(selected_server.to_s)
    end
  end

  scenario 'admin cannot change maps and server until voting has ended' do
    gather.update!(status: Gather::STATE_VOTING)

    Capybara.using_session('admin') do
      sign_in_via_session(admin)
      visit edit_gather_path(gather)

      expect(page).to have_no_button('Change Maps and Server')
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

  scenario 'admin only sees the new gather control before the gather starts' do
    gather.update!(status: Gather::STATE_RUNNING)

    Capybara.using_session('admin') do
      sign_in_via_session(admin)
      visit edit_gather_path(gather)

      expect(page).to have_button('Start New Gather')
      expect(page).to have_no_button('Restart Gather')
      expect(page).to have_no_button('Change Turn')
      expect(page).to have_no_button('Replace Player')
    end
  end

  scenario 'admin adds the last player and other players see voting start' do
    open_gather = FactoryBot.create(:gather, maps_count: 3, servers_count: 2)
    joined_users = FactoryBot.create_list(:user, Gather::FULL - 1, raw_password: 'password123')
    joined_users.each { |user| open_gather.gatherers.create!(user: user) }
    added_user = FactoryBot.create(:user, raw_password: 'password123')

    Capybara.using_session('observer') do
      sign_in_via_session(joined_users.first)
      visit gather_path(open_gather)
      expect(page).to have_content('1 more needed')
    end

    Capybara.using_session('admin') do
      sign_in_via_session(admin)
      visit edit_gather_path(open_gather)
      fill_in 'Username', with: added_user.username
      click_button 'Add Player'
      expect(page).to have_content(I18n.t('gathers.join'))
    end

    expect(open_gather.reload.status).to eq(Gather::STATE_VOTING)
    expect(open_gather.gatherers.of_user(added_user)).to exist

    Capybara.using_session('observer') do
      expect(page).to have_content('Please vote captains and maps.', wait: 10)
      expect(page).to have_content(added_user.username)
    end
  end

  scenario 'admin cannot add a player to a full gather' do
    gather.update!(status: Gather::STATE_RUNNING)

    Capybara.using_session('admin') do
      sign_in_via_session(admin)
      visit edit_gather_path(gather)

      expect(page).to have_no_button('Add Player')
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
      expect(page).to have_selector('#notification .message', text: I18n.t('gathers.create'))
      expect(Gather.count).to eq(gather_count + 1)

      new_gather = Gather.where(category: gather.category).order('id DESC').first
      expect(new_gather).not_to be_nil
    end

    joiner = FactoryBot.create(:user, raw_password: 'password123')
    sign_in_and_join_gather('joiner', joiner, new_gather)
  end
end
