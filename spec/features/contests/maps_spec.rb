# frozen_string_literal: true

require 'rails_helper'

RSpec.feature 'Maps management for contests', :js, type: :feature do
  let!(:admin) { create(:user, :admin) }
  let!(:contest) { create(:contest) }
  let!(:added_map) { create(:map) }
  let!(:removed_map) { create(:map) }
  let!(:retained_map) { create(:map) }

  before do
    sign_in_as(admin)
  end

  scenario 'Add a map to the contest from the contest edit view', :aggregate_failures do
    visit edit_contest_path(contest, contest: 'maps')
    expect(page).to have_css('#maps')

    select added_map.name, from: 'map'
    click_button 'Add map'

    expect(page).to have_css('#maps table.maps', text: added_map.name, wait: 5)
  end

  scenario 'Edit link goes to the correct map edit page', :aggregate_failures do
    contest.maps << added_map
    contest.save!

    visit edit_contest_path(contest, contest: 'maps')
    expect(page).to have_css('#maps')

    row = find('#maps table.maps tr', text: added_map.name)
    within(row) do
      find("a[href='#{edit_map_path(added_map)}']").click
    end

    expect(page).to have_current_path(edit_map_path(added_map))
  end

  scenario 'Delete a map from the contest edit view', :aggregate_failures do
    contest.maps << removed_map
    contest.maps << retained_map
    contest.save!

    visit edit_contest_path(contest, contest: 'maps')
    expect(page).to have_css('#maps')

    rows_before = nil
    within('#maps') do
      rows = all('table.maps tr', visible: :all)
      rows_before = rows.size - 1
      row = find('tr', text: removed_map.name, visible: :all)

      within(row) do
        accept_confirm do
          find("a[data-method='delete']").click
        end
      end
    end

    expect(page).to have_current_path(edit_contest_path(contest, contest: 'maps'))
    expect(page).to have_css('#maps table.maps')
    within('#maps') do
      rows_after = all('table.maps tr', visible: :all).size - 1
      expect(rows_after).to eq(rows_before - 1)
    end

    # Check in DB
    contest.reload
    expect(contest.maps).not_to include(removed_map)
    expect(contest.maps).to include(retained_map)
  end
end
