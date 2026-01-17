require 'rails_helper'

RSpec.feature 'Gather multi-user flow', type: :feature, js: true do
  # Use a real browser + app server.
  before(:all) do
    Capybara.server = :puma, { Silent: true }
    Capybara.javascript_driver = :selenium_chrome_headless
    Capybara.default_max_wait_time = 5
  end

  let!(:gather) { FactoryBot.create(:gather) }

  before do
    # Add some maps to vote on
    10.times do |i|
      gather.maps.create!(name: "ns_map#{i + 1}")
    end

    # Add some servers to vote on
    5.times do |i|
      gather.servers.create!(name: "Server #{i + 1}",
                             ip: "192.168.1.#{i + 1}",
                             port: "270#{i + 1}",
                             dns: "server#{i + 1}.example.com")
    end
  end

  # create users with a known password so we can sign them in via UI
  let!(:users) { FactoryBot.create_list(:user, 12, raw_password: 'password123') }

  # Helper to sign in a user in a separate browser session.
  # Tries common login field names; adapt labels/selectors if your app differs.
  def sign_in_session(session_name, user_index)
    Capybara.using_session(session_name) do
      # Try visiting a login route; fall back to root if login_path isn't available
      visit root_path

      # Try several common form field name variations
      if page.has_field?('login[username]') && page.has_field?('login[password]')
        fill_in 'login[username]', with: users[user_index].username
        fill_in 'login[password]', with: 'password123'
      end

      # Try clicking common submit buttons
      begin
        click_button('Login')
      rescue StandardError
        nil
      end

      # Basic post-login expectation — adjust to your app's flash/user display
      expect(page).to have_content('Login Successful')
    end
  end

  # Helper to visit gather page and join. Assumes user is already signed in in this session.
  def open_and_join(session_name, user_index)
    Capybara.using_session(session_name) do
      visit gather_path(gather)

      # Wait for join UI
      expect(page).to have_content('Join')

      # FIXME: There is a 5s window here when the page is refreshed
      # Might need a better solution.
      check 'gatherer[confirm]'
      click_link 'Click to join gather!'

      # After joining, expect participant to appear in UI. Replace selector/text as needed.
      expect(page).to have_content('You have joined the Gather.')
    end
  end

  # Vote randomly on maps (each user can cast `votes` clicks). Resilient to transient stale-node errors.
  def vote_random_maps(session_name, votes: 2)
    Capybara.using_session(session_name) do
      votes.times do
        attempts = 0
        begin
          ul = find('ul#map-votes', wait: 5)
          links = ul.all('a')
          raise Capybara::ElementNotFound, 'no map links found' if links.empty?

          links.sample.click
          sleep(rand(0.05..0.25))
        rescue Selenium::WebDriver::Error::UnknownError => e
          raise unless e.message.include?('Node with given id does not belong to the document')

          attempts += 1
          retry if attempts < 6
          raise
        rescue Capybara::ElementNotFound, StandardError
          attempts += 1
          sleep 0.2
          retry if attempts < 6
          raise
        end
      end
    end
  end

  scenario '12 people open the gather page, join and start the captain vote' do
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
      expect(page).to have_content('Vote Captains')
    end

    # All users cast two random map votes
    users.each_with_index do |_, i|
      vote_random_maps("user_#{i}", votes: 2)
    end

    # Wait for voting phase to finish (about 1 minute). Wait up to 70s for the voting UI to disappear.
    Capybara.using_session('user_0') do
      # Wait up to 70s for the voting UI to disappear.
      expect(page).to have_content('Captains are picking the teams', wait: 61)
    end

    # Captains pick teams. First we need to find out who the captains are.
    gather.reload
    captain1 = gather.captain1.user
    captain2 = gather.captain2.user
    expect(captain1).not_to be_nil
    expect(captain2).not_to be_nil

    # Each captain picks 6 players (customizable picking order). Last is auto-picked.
    pick_order = [captain1, captain2, captain2, captain1, captain1, captain2, captain2, captain1, captain1]

    pick_order.each do |picking_captain|
      session_name = "user_#{users.index(picking_captain)}"
      Capybara.using_session(session_name) do
        attempts = 0
        begin
          ul = find('ul#lobby-gatherers', wait: 5)

          # Find candidate radio inputs for picking a player
          radios = ul.all('input[type="radio"]')

          if radios.empty?
            puts page.html
            raise Capybara::ElementNotFound, 'no available player radios found'
          end

          # Choose a random radio (player) to pick
          radios.sample.click

          # Ensure the "Pick" button exists and click it (adjust selector/text if needed)
          click_button('Pick')

          # Print the captain and picked player for logging
          # puts "#{picking_captain.username} picked a player."

          sleep(rand(0.05..0.25))
        rescue Selenium::WebDriver::Error::UnknownError => e
          raise unless e.message.include?('Node with given id does not belong to the document')

          attempts += 1
          retry if attempts < 6
          raise
        rescue Capybara::ElementNotFound, StandardError
          attempts += 1
          sleep 0.2
          retry if attempts < 6
          raise
        end
      end

      # Should say "Gather finished" after last pick to anyone
      Capybara.using_session('user_0') do
        expect(page).to have_content('Gather finished', wait: 5)
      end
    end
  end
end
