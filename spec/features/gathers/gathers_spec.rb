require 'rails_helper'

RSpec.feature 'Gather multi-user flow', type: :feature, js: true do
  # Use a real browser + app server.
  before(:all) do
    Capybara.javascript_driver = :selenium_chrome_headless
    Capybara.default_max_wait_time = 5
  end

  # Create a gather with maps and servers, and 12 users
  let!(:gather) { FactoryBot.create(:gather, maps_count: 10, servers_count: 5) }
  let!(:users) { FactoryBot.create_list(:user, 12, raw_password: 'password123') }

  scenario '12 players join, vote on maps, pick teams, and finish the gather' do
    # Sign in + open 12 independent browser sessions and join
    users.each_with_index do |_, i|
      sign_in_session("user_#{i}", i)
      open_and_join("user_#{i}", i)
    end

    # Verify participant count converges to 12 from one session (replace selector)
    Capybara.using_session('user_0') do
      # Verify in DB that gather has 12 gatherers (participants)
      gather.reload
      expect(gather.gatherers.count).to eq(12)
    end

    # Start captain vote from one participant
    Capybara.using_session('user_0') do
      # Confirm vote UI is visible (replace text/selector to match your app)
      safe_expect_text('Vote Captains')
    end

    RSpec.configuration.reporter.message('All users joined the gather and voting has started.')

    # All users cast two random map votes
    users.each_with_index do |_, i|
      vote_random_maps("user_#{i}", votes: 2)
    end

    # All users cast two random server votes
    users.each_with_index do |_, i|
      vote_random_servers("user_#{i}", votes: 2)
    end

    # Verify in DB that gather has map votes recorded
    # Ii will always be 22 or less because last joiner can't vote on maps
    gather.reload
    expect(gather.map_votes.count).to be >= 20

    # Verify in DB that gather has server votes recorded
    gather.reload
    expect(gather.server_votes.count).to be >= 20

    # Wait for voting phase to finish (about 1 minute). Wait up to 70s for the voting UI to disappear.
    Capybara.using_session('user_0') do
      # Wait up to 70s for the voting UI to disappear.
      safe_expect_text('Captains are picking the teams', wait: 70)
    end

    # Find and verify captains are assigned in DB
    gather.reload
    captain1 = gather.captain1.user
    captain2 = gather.captain2.user
    expect(captain1).not_to be_nil
    expect(captain2).not_to be_nil

    # Verify that captains are the two most-voted users
    expect(gather.captain1.id).to eq(gather.gatherers.most_voted[1].id)
    expect(gather.captain2.id).to eq(gather.gatherers.most_voted[0].id)

    RSpec.configuration.reporter.message('Captain voting has ended, picking phase has started.')

    # Each captain picks 6 players (customizable picking order). Last is auto-picked.
    pick_order = [captain1, captain2, captain2, captain1, captain1, captain2, captain2, captain1, captain1]

    pick_order.each do |picking_captain|
      session_name = "user_#{users.index(picking_captain)}"
      Capybara.using_session(session_name) do
        # Choose a random radio (player) to pick
        safe_click { find('ul#lobby-gatherers', wait: 5).all('input[type="radio"]').sample.click }

        # Ensure the "Pick" button exists and click it (adjust selector/text if needed)
        safe_click { find('input[value="Pick"]').click }

        # Confirm pick success message appears
        safe_expect_text('You have picked a player for your team.', wait: 5)

        # Print the captain and picked player for logging
        # puts "#{picking_captain.username} picked a player."

        sleep(rand(0.05..0.25))
      end
    end

    # Check in DB that both teams have 6 players
    gather.reload
    expect(gather.gatherers.team(1).count).to eq(6)
    expect(gather.gatherers.team(2).count).to eq(6)

    # Should say "Gather finished" after last pick to anyone
    Capybara.using_session('user_0') do
      safe_expect_text('Gather finished', wait: 5)
    end
  end
end
