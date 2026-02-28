require 'rails_helper'

RSpec.feature 'Gather leave', type: :feature, js: true do
  let!(:gather) { FactoryBot.create(:gather, maps_count: 3, servers_count: 2) }
  let!(:user) { FactoryBot.create(:user, raw_password: 'password123') }

  scenario 'joined player can leave via Leave Gather button' do
    sign_in_and_join_gather('leaver', user, gather)

    Capybara.using_session('leaver') do
      gather.reload
      expect(gather.gatherers.of_user(user).count).to eq(1)

      visit gather_path(gather)
      expect(page).to have_button('Leave Gather', wait: 5)

      accept_confirm do
        click_button 'Leave Gather'
      end

      gather.reload
      expect(gather.gatherers.of_user(user).count).to eq(0)
      expect(page).to have_button('Click to join gather!', wait: 5)
    end
  end
end
