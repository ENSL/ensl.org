require 'rails_helper'

RSpec.feature 'Maps management for contests', type: :feature, js: true do
  let!(:admin) { create(:user, :admin) }
  let!(:contest) { create(:contest) }
  let!(:map1) { create(:map) }
  let!(:map2) { create(:map) }
  let!(:map3) { create(:map) }

  before do
    sign_in_as(admin)
    visit edit_contest_path(contest)
    find("a[href='#maps']").click
    expect(page).to have_css('#maps')
  end

  scenario 'Add a map to the contest from the contest edit view', :aggregate_failures do
    select map1.name, from: 'map'
    click_button 'Add map'

    expect(page).to have_current_path(/contests/)
    find("a[href='#maps']").click
    expect(page).to have_css('#maps table.maps')
    expect(page).to have_content(map1.name)
  end

  scenario 'Delete a map from the contest edit view', :aggregate_failures do
    # Ensure map is present first
    select map2.name, from: 'map'
    click_button 'Add map'
    find("a[href='#maps']").click
    expect(page).to have_css('#maps table.maps')
    expect(page).to have_content(map2.name)

    rows_before = nil
    within('#maps') do
      rows = all('table.maps tr', visible: :all)
      rows_before = rows.size - 1
      row = find('tr', text: map2.name, visible: :all)
      within(row) do
        delete_link = find('a[data-submit-form]', visible: :all)
        form = delete_link.find_xpath('ancestor::form').first
        form_id = form[:id]

        page.execute_script('window._orig_confirm = window.confirm; window.confirm = function(){return true};')
        page.execute_script("document.getElementById('#{form_id}').submit();")
        page.execute_script('if(window._orig_confirm) window.confirm = window._orig_confirm')
      end
    end

    expect(page).to have_current_path(edit_contest_path(contest))
    find("a[href='#maps']").click
    expect(page).to have_css('#maps table.maps')
    within('#maps') do
      rows_after = all('table.maps tr', visible: :all).size - 1
      expect(rows_after).to eq(rows_before - 1)
      expect(page).not_to have_selector("form#delete_map_#{map2.id}")
    end
  end
end
