# frozen_string_literal: true

require 'rails_helper'

RSpec.feature 'Gather start time', type: :feature do
  scenario 'shows when voting started on a finished gather' do
    gather = create(:gather)
    create_list(:gatherer, Gather::FULL - 1, gather: gather, created_at: 2.hours.ago)
    started_at = Time.zone.local(2026, 8, 22, 14, 35)
    create(:gatherer, gather: gather, created_at: started_at)
    gather.update_column(:status, Gather::STATE_FINISHED)

    visit gather_path(gather)

    expect(page).to have_css('.gather-started-at', text: 'Started 22 August 26 14:35')
  end

  scenario 'does not show a start time while the gather is still active' do
    gather = create(:gather)
    create_list(:gatherer, Gather::FULL, gather: gather)

    visit gather_path(gather)

    expect(page).not_to have_css('.gather-started-at')
  end
end
