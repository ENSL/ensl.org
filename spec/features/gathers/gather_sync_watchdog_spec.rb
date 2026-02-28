require 'rails_helper'
require 'timeout'

RSpec.feature 'Gather sync watchdog', type: :feature, js: true do
  let!(:gather) { create(:gather) }
  let!(:user) { create(:user, raw_password: 'password123') }

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
end
