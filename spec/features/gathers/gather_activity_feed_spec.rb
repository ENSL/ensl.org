# frozen_string_literal: true

require 'rails_helper'

RSpec.feature 'Gather activity feed', type: :feature, js: true do
  let!(:gather) { FactoryBot.create(:gather, maps_count: 3, servers_count: 2) }
  let!(:joiner) { FactoryBot.create(:user, raw_password: 'password123') }
  let!(:viewer) { FactoryBot.create(:user, raw_password: 'password123') }

  scenario 'a viewer sees another player join the activity feed live, without reloading' do
    Capybara.using_session('viewer') do
      sign_in_via_session(viewer)
      visit_gather_with_retry(gather)
      expect(page).to have_no_content("#{joiner.username} joined the gather")

      # gather_sync.js also polls /version and reloads the frame on a missed broadcast,
      # which would make this assertion pass even if the activity broadcast itself were
      # broken. Kill that fallback so only a real ActionCable push can update the page.
      page.execute_script(<<~JS)
        window.fetch = new Proxy(window.fetch, {
          apply(target, thisArg, args) {
            const url = args[0]
            if (typeof url === 'string' && url.includes('/version')) return Promise.reject(new Error('disabled for test'))
            return target.apply(thisArg, args)
          }
        })
      JS
    end

    sign_in_and_join_gather('joiner', joiner, gather)

    Capybara.using_session('viewer') do
      expect(page).to have_content("#{joiner.username} joined the gather", wait: 5)
    end
  end
end
