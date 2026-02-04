require 'rails_helper'

RSpec.feature 'Weeks management', type: :feature, js: true do
  let!(:admin) { create(:user, :admin) }
  let!(:contest) { create(:contest) }
  let!(:map1) { create(:map) }
  let!(:map2) { create(:map) }

  before do
    contest.maps << [map1, map2]
    sign_in_as(admin)
  end

  def open_weeks_tab
    visit edit_contest_path(contest)
    find("a[href='#weeks']").click
    expect(page).to have_css('#weeks table.weeks')
  end

  scenario 'Create a week from the new week view with JS', :aggregate_failures do
    visit new_week_path(id: contest.id)

    fill_in 'week_name', with: 'Spec Week'
    select map1.name, from: 'week_map1_id'
    select map2.name, from: 'week_map2_id'
    select (Date.today + 7).day.to_s, from: 'week_start_date_3i'

    click_button 'Save Week'

    expect(page).to have_current_path(/weeks|contests/)
    open_weeks_tab
    expect(page).to have_content('Spec Week')
  end

  scenario 'Update a week via the edit view with JS', :aggregate_failures do
    week = create(:week, contest: contest, map1: map1, map2: map2)
    visit edit_week_path(week)

    fill_in 'week_name', with: 'Updated Week'
    click_button 'Save Week'

    expect(page).to have_current_path(/weeks|contests/)
    open_weeks_tab
    expect(page).to have_content('Updated Week')
  end

  scenario 'Delete a week from the contest edit view', :aggregate_failures do
    week = create(:week, contest: contest, map1: map1, map2: map2)
    open_weeks_tab

    # Find the row for our week and use the form-backed delete link
    within('#weeks') do
      row = find('tr', text: week.name, visible: :all)
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
    open_weeks_tab
    expect(page).not_to have_content(week.name)
  end
end
