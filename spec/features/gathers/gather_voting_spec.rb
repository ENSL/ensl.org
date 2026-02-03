require 'rails_helper'

RSpec.feature 'Gather voting UI', type: :feature, js: true do
  before(:all) do
    Capybara.javascript_driver = :selenium_chrome_headless
    Capybara.default_max_wait_time = 5
  end

  let!(:gather) { FactoryBot.create(:gather, maps_count: 3, servers_count: 2) }
  let!(:users) { FactoryBot.create_list(:user, 3, raw_password: 'password123') }

  scenario 'users can cast map and server votes while gather is running' do
    users.each_with_index do |_, i|
      sign_in_session("vote_user_#{i}", i)
      open_and_join("vote_user_#{i}", i)
    end

    Capybara.using_session('vote_user_0') do
      safe_expect_text('Map Votes')
      safe_expect_text('Server Votes')
    end

    vote_random_maps('vote_user_0', votes: 1)
    vote_random_servers('vote_user_0', votes: 1)

    gather.reload
    expect(gather.map_votes.count).to be >= 1
    expect(gather.server_votes.count).to be >= 1
  end

  scenario 'captain voting transitions to picking with captains assigned' do
    users.each_with_index do |_, i|
      sign_in_session("cap_vote_user_#{i}", i)
      open_and_join("cap_vote_user_#{i}", i)
    end

    gather.update!(status: Gather::STATE_VOTING)

    Capybara.using_session('cap_vote_user_0') do
      visit gather_path(gather)
      safe_expect_text('Vote Captains')
      safe_expect_text('Please vote captains and maps.')
    end

    Capybara.using_session('cap_vote_user_0') do
      visit gather_path(gather)
      links = all('table#gatherers a.vote-link')
      raise 'No captain vote links found' if links.empty?

      first, second = links.uniq.first(2)
      safe_click { find('table#gatherers a.vote-link', text: first.text, match: :first).click }
      safe_click { find('table#gatherers a.vote-link', text: second.text, match: :first).click } if second
    end

    gather.reload
    expect(gather.gatherer_votes.count).to be >= 1

    gather.update_column(:updated_at, 2.minutes.ago)
    gather.refresh(nil)
    gather.reload

    expect(gather.status).to eq(Gather::STATE_PICKING)
    expect(gather.captain1).not_to be_nil
    expect(gather.captain2).not_to be_nil

    Capybara.using_session('cap_vote_user_1') do
      visit gather_path(gather)
      expect(
        page.has_content?('Captains are picking the teams', wait: 5) ||
          page.has_content?('It is your turn, please pick a player from the lobby!', wait: 5)
      ).to be(true)
    end
  end
end
