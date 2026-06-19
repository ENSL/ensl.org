# frozen_string_literal: true

require 'rails_helper'
require 'timeout'

RSpec.feature 'Gather sync watchdog', type: :feature, js: true do
  let!(:gather) { create(:gather, maps_count: 3, servers_count: 2) }
  let!(:user) { create(:user, raw_password: 'password123') }
  let!(:admin) { create(:user, :admin, raw_password: 'password123') }

  scenario 'forces a hard reload after prolonged sync failures' do
    sign_in_via_session(user)
    visit gather_path(gather)

    expect(page).to have_selector('#gather', wait: 5)

    execute_script <<~JS
      localStorage.removeItem('gather_sync_force_reload')
      window.addEventListener('gather-sync:force-reload', () => {
        localStorage.setItem('gather_sync_force_reload', '1')
      }, { once: true })

      const gatherEl = document.getElementById('gather')
      gatherEl.dataset.gatherSyncGatherIdValue = '0'
      gatherEl.dataset.gatherSyncDeadReloadAfterValue = '1000'
      window.dispatchEvent(new Event('online'))
    JS

    Timeout.timeout(8) do
      loop do
        flag = evaluate_script("localStorage.getItem('gather_sync_force_reload')")
        break if flag == '1'

        sleep 0.1
      end
    end

    expect(evaluate_script("localStorage.getItem('gather_sync_force_reload')")).to eq('1')
  end

  scenario 'renders gather music controls next to admin button' do
    sign_in_via_session(admin)
    visit gather_path(gather)

    expect(page).to have_selector('#gather-stats .gather-controls #gather-music.gather-audio', wait: 5, visible: :all)
    expect(page).to have_selector('#gather-stats .gather-controls #mute.button', text: 'Mute', wait: 5)
    expect(page).to have_selector('#gather-stats .gather-controls a.admin.button', text: 'Admin Page', wait: 5)

    controls_order = evaluate_script("Array.from(document.querySelectorAll('#gather-stats .gather-controls > *')).map((el) => el.id || el.className)")
    expect(controls_order.first).to eq('gather-music')
  end

  scenario 'attempts to autoplay gather music when voting starts' do
    gather.update!(status: Gather::STATE_VOTING)
    gather.gatherers.create!(user: user)

    sign_in_via_session(user)
    visit gather_path(gather)

    autoplay_attempted = evaluate_script("document.getElementById('gather-music').dataset.autoplayAttempted")
    expect(autoplay_attempted).to eq('1')
  end

  scenario 'stops music immediately when user votes' do
    gather.update!(status: Gather::STATE_RUNNING)
    gather.gatherers.create!(user: user)

    sign_in_via_session(user)
    visit gather_path(gather)

    expect(page).to have_selector('.vote-link', wait: 5)

    execute_script <<~JS
      const audio = document.getElementById('gather-music')
      const voteForm = document.getElementById('vote_form')
      if (voteForm) {
        voteForm.submit = function() { window.__voteFormSubmitIntercepted = true }
      }

      audio.pause = function() { this.dataset.pauseCalled = '1' }
    JS

    first('.vote-link', wait: 5).click

    pause_called = evaluate_script("document.getElementById('gather-music').dataset.pauseCalled")
    expect(pause_called).to eq('1')
  end

  scenario 'does not attempt autoplay when user has already voted' do
    gather.update!(status: Gather::STATE_PICKING)
    gather.gatherers.create!(user: user)

    gather_map = gather.gather_maps.first
    gather_map.real_votes.create!(user: user)

    sign_in_via_session(user)
    visit gather_path(gather)

    autoplay_attempted = evaluate_script("document.getElementById('gather-music').dataset.autoplayAttempted")
    expect(autoplay_attempted).to be_nil
  end

  scenario 'user can mute and unmute before gather start' do
    gather.update!(status: Gather::STATE_RUNNING)

    sign_in_via_session(admin)
    visit gather_path(gather)

    click_button 'Mute'
    expect(evaluate_script("document.getElementById('gather-music').muted")).to eq(true)
    expect(page).to have_button('Unmute', id: 'mute')

    click_button 'Unmute'
    expect(evaluate_script("document.getElementById('gather-music').muted")).to eq(false)
    expect(page).to have_button('Mute', id: 'mute')
  end

  scenario 'user can mute and unmute after gather start' do
    gather.update!(status: Gather::STATE_PICKING)

    sign_in_via_session(admin)
    visit gather_path(gather)

    click_button 'Mute'
    expect(evaluate_script("document.getElementById('gather-music').muted")).to eq(true)
    expect(page).to have_button('Unmute', id: 'mute')

    click_button 'Unmute'
    expect(evaluate_script("document.getElementById('gather-music').muted")).to eq(false)
    expect(page).to have_button('Mute', id: 'mute')
  end
end
