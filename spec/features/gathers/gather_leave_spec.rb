# frozen_string_literal: true

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

  scenario 'idle time shown next to a player matches their real lastvisit gap, visible to other viewers' do
    idle_player = FactoryBot.create(:user, raw_password: 'password123')
    viewer = FactoryBot.create(:user, raw_password: 'password123')

    sign_in_and_join_gather('idle_player', idle_player, gather)

    Capybara.using_session('viewer') do
      sign_in_via_session(viewer)
      visit gather_path(gather)

      expect(page).to have_content('( 0 m )')

      # Advance the clock without the idle player making any request of their own,
      # so their lastvisit stays frozen - only the viewer's page reload moves.
      Timecop.travel(5.minutes.from_now) do
        visit gather_path(gather)

        expected_idle_minutes = ((Time.now.utc - idle_player.reload.lastvisit) / 60).floor
        expect(expected_idle_minutes).to eq(5)
        expect(page).to have_content("( #{expected_idle_minutes} m )")
      end
    end
  end

  describe 'automated idle kicking' do
    # Kicking is checked whenever the gather page is visited (GathersController#show)
    # or polled (#version), not via a direct model call - confirm both ways here.
    it 'leaves an idle player in the gather while kicking is disabled (the default)' do
      idle_player = FactoryBot.create(:user)
      viewer = FactoryBot.create(:user, raw_password: 'password123')
      gatherer = gather.gatherers.create!(user: idle_player)
      idle_player.update!(lastvisit: (Gatherer::IDLE_TIME + 60).seconds.ago.utc)

      expect(Gatherer.idle_kick_enabled?).to be(false)

      Capybara.using_session('viewer') do
        sign_in_via_session(viewer)
        visit gather_path(gather)

        expect(page).to have_content(idle_player.username)
      end

      expect(Gatherer.exists?(gatherer.id)).to be(true)
    end

    it 'removes only the idle player once explicitly enabled, discovered by visiting the gather page' do
      idle_player = FactoryBot.create(:user)
      active_player = FactoryBot.create(:user)
      viewer = FactoryBot.create(:user, raw_password: 'password123')
      idle_gatherer = gather.gatherers.create!(user: idle_player)
      active_gatherer = gather.gatherers.create!(user: active_player)

      idle_player.update!(lastvisit: (Gatherer::IDLE_TIME + 60).seconds.ago.utc)
      active_player.update!(lastvisit: Time.now.utc)

      previous = ENV['GATHER_IDLE_KICK_ENABLED']
      ENV['GATHER_IDLE_KICK_ENABLED'] = 'true'
      begin
        expect(Gatherer.idle_kick_enabled?).to be(true)

        Capybara.using_session('viewer') do
          sign_in_via_session(viewer)
          visit gather_path(gather)

          expect(page).to have_content(active_player.username)
          expect(page).not_to have_content(idle_player.username)
        end
      ensure
        ENV['GATHER_IDLE_KICK_ENABLED'] = previous
      end

      expect(Gatherer.exists?(idle_gatherer.id)).to be(false)
      expect(Gatherer.exists?(active_gatherer.id)).to be(true)
    end
  end
end
