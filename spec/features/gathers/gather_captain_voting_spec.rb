require 'rails_helper'

RSpec.feature 'Gather voting phase - find nil:id error when voting', type: :feature, js: true do
  before(:all) do
    Capybara.default_max_wait_time = 5
  end

  # Create a gather with maps and servers; voting starts after 12 users join
  let!(:gather) { FactoryBot.create(:gather, maps_count: 10, servers_count: 5) }
  let!(:users) { FactoryBot.create_list(:user, 12, raw_password: 'password123') }

  scenario 'User votes for captains, maps, and servers without errors', :debug do
    # Sign in + open 12 independent browser sessions and join
    users.each_with_index do |_, i|
      sign_in_session("user_#{i}", i)
      open_and_join("user_#{i}", i)
    end

    # Verify all 12 have joined
    gather.reload
    expect(gather.gatherers.count).to eq(12)
    expect(gather.status).to eq(Gather::STATE_VOTING)

    Capybara.using_session('user_0') do
      visit gather_path(gather)
      assert_no_log_errors('on initial page load')

      safe_expect_text('Vote Captains')

      vote_deadline = voting_deadline(buffer_seconds: 3)

      vote_random_captains('user_0', votes: 2, deadline: vote_deadline)
      assert_no_log_errors('after voting for captain')

      # Vote for maps and servers using shared helpers
      vote_random_maps('user_0', votes: 2, deadline: vote_deadline)
      assert_no_log_errors('after voting for maps')

      vote_random_servers('user_0', votes: 2, deadline: vote_deadline)
      assert_no_log_errors('after voting for servers')

      puts 'All votes cast without exceptions!'
    end
  end
end
