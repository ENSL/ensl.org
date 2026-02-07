require 'rails_helper'

RSpec.feature 'Maps management for contests', type: :feature, js: true do
  let!(:admin) { create(:user, :admin) }
  let!(:contest) { create(:contest) }
  let!(:map1) { create(:map) }
  let!(:map2) { create(:map) }
  let!(:map3) { create(:map) }

  before do
    sign_in_as(admin)
  end

  scenario 'Add a map to the contest from the contest edit view', :aggregate_failures do
    visit edit_contest_path(contest, contest: 'maps')
    expect(page).to have_css('#maps')

    select map1.name, from: 'map'
    click_button 'Add map'

    expect(page).to have_css('#maps table.maps', text: map1.name, wait: 5)
  end

  scenario 'Edit link goes to the correct map edit page', :aggregate_failures do
    contest.maps << map1
    contest.save!

    visit edit_contest_path(contest, contest: 'maps')
    expect(page).to have_css('#maps')

    row = find('#maps table.maps tr', text: map1.name)
    within(row) do
      find("a[href='#{edit_map_path(map1)}']").click
    end

    expect(page).to have_current_path(edit_map_path(map1))
  end

  scenario 'Delete a map from the contest edit view', :aggregate_failures do
    contest.maps << map2
    contest.maps << map3
    contest.save!

    visit edit_contest_path(contest, contest: 'maps')
    expect(page).to have_css('#maps')

    rows_before = nil
    within('#maps') do
      rows = all('table.maps tr', visible: :all)
      rows_before = rows.size - 1
      row = find('tr', text: map2.name, visible: :all)

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
    expect(contest.maps).not_to include(map2)
    expect(contest.maps).to include(map3)
  end
end
