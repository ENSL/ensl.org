# frozen_string_literal: true

require 'rails_helper'

RSpec.feature 'Bracket Admin Integration test', type: :feature, js: true do
  let!(:admin) { create(:user, :admin) }

  scenario 'Admin edits bracket and assigns teams and matches to cells' do
    # Create contest with bracket that has teams and matches already populated
    contest = create(:contest, :bracket_ready)
    teams = contest.contesters.map(&:team)
    bracket = create(:bracket, :normal, contest: contest, teams_pool: teams)

    sign_in_via_session(admin)
    visit edit_bracket_path(bracket)

    expect(page).to have_content('Editing Bracket')
    expect(page).to have_selector('table.brackets')

    # Change the name
    fill_in 'bracket_name', with: 'Updated Bracket Name'

    # Get the cell select dropdowns
    selects = all('select[name*="cell"]').to_a
    expect(selects.length).to be_positive

    # Find selects that have teams and matches available
    team_select = selects.find { |s| s.all('option[value*="contester_"]', wait: false).any? }
    match_select = selects.find { |s| s.all('option[value*="match_"]', wait: false).any? && s != team_select }
    disabled_select = (selects - [team_select, match_select]).first

    expect(team_select).to be_present
    expect(match_select).to be_present
    expect(disabled_select).to be_present

    # Extract positions
    team_cell_pos = extract_cell_position(team_select)
    match_cell_pos = extract_cell_position(match_select)
    disabled_pos = extract_cell_position(disabled_select)

    # Assign a team to first select
    team_option = team_select.all('option[value*="contester_"]', wait: false).first
    team_option.select_option

    # Assign a match to second select
    match_option = match_select.all('option[value*="match_"]', wait: false).first
    match_option.select_option

    # Mark third select as disabled
    disabled_select.find("option[value='disabled']").select_option

    # Submit the form
    click_button 'Update'

    # Wait for redirect to complete and verify we're back on edit page
    expect(page).to have_content('Editing Bracket', wait: 10)

    # Verify flash message is displayed
    expect(page).to have_selector('#notification .message.notice', wait: 5)
    expect(page).to have_content('successfully updated')

    # Verify team was actually saved
    bracket.reload
    team_bracketer = bracket.bracketers.pos(team_cell_pos[:row], team_cell_pos[:col]).first
    expect(team_bracketer).to be_present
    expect(team_bracketer.team_id).to be_present

    # Verify match was actually saved
    match_bracketer = bracket.bracketers.pos(match_cell_pos[:row], match_cell_pos[:col]).first
    expect(match_bracketer).to be_present
    expect(match_bracketer.match_id).to be_present

    # Verify disabled cell was set correctly
    disabled_bracketer = bracket.bracketers.pos(disabled_pos[:row], disabled_pos[:col]).first
    expect(disabled_bracketer).to be_present
    expect(disabled_bracketer.disabled).to be true

    # Visit bracket view to verify display
    visit bracket_path(bracket)
    expect(page).to have_content(bracket.name)
  end

  scenario 'Admin can create multiple brackets for tournament rounds' do
    contest = create(:contest, :bracket_ready)

    sign_in_via_session(admin)
    visit edit_contest_path(contest)

    # Click on brackets tab and wait for it to be active
    brackets_tab = find("a[href='#brackets']")
    brackets_tab.click

    # Wait for the tab content to be visible
    expect(page).to have_selector('#brackets', visible: true, wait: 5)

    # Create first bracket for round of 16
    within('#brackets') do
      fill_in 'bracket_name', with: 'Round of 16'
      fill_in 'bracket_slots', with: '16'
      click_button 'Add Bracket'
    end

    expect(page).to have_content('Bracket was successfully created', wait: 5)

    # Navigate back to contest edit page to create another bracket
    visit edit_contest_path(contest)

    # Click on brackets tab again
    brackets_tab = find("a[href='#brackets']")
    brackets_tab.click

    # Wait for the tab content to be visible
    expect(page).to have_selector('#brackets', visible: true, wait: 5)

    # Create second bracket for finals
    within('#brackets') do
      fill_in 'bracket_name', with: 'Finals'
      fill_in 'bracket_slots', with: '4'
      click_button 'Add Bracket'
    end

    expect(page).to have_content('Bracket was successfully created', wait: 5)

    contest.reload
    expect(contest.brackets.count).to eq(2)
    expect(contest.brackets.pluck(:name)).to include('Round of 16', 'Finals')
    expect(contest.brackets.pluck(:slots)).to include(16, 4)
  end

  scenario 'Admin can set disabled and custom text in bracket cells' do
    # Create bracket with mixed content (teams and matches)
    contest = create(:contest, :bracket_ready)
    bracket = create(:bracket, :mixed, contest: contest)

    sign_in_via_session(admin)
    visit edit_bracket_path(bracket)

    expect(page).to have_content('Editing Bracket')
    expect(page).to have_selector('table.brackets')

    # Get all cell select dropdowns
    selects = all('select[name*="cell"]')
    expect(selects.length).to be_positive

    # Randomly select up to 3 cells to modify
    selected_cells = selects.sample([3, selects.length].min)
    disabled_positions = []
    custom_text_positions = []

    selected_cells.each_with_index do |select, index|
      cell_pos = extract_cell_position(select)

      case index
      when 0
        # Set first cell as disabled
        select.find("option[value='disabled']").select_option
        disabled_positions << cell_pos
      when 1
        # Set second cell with custom text
        custom_text_positions << { **cell_pos, text: 'Finalist TBD' }
      when 2
        # Set third cell as disabled
        select.find("option[value='disabled']").select_option
        disabled_positions << cell_pos
      end
    end

    # Fill in custom text fields for selected positions
    custom_text_positions.each do |pos|
      custom_field = find("input[name='cell_custom[#{pos[:row]}][#{pos[:col]}]']")
      custom_field.set(pos[:text])
    end

    # Submit the form
    click_button 'Update'

    # Wait for redirect and verify flash message
    expect(page).to have_content('Editing Bracket', wait: 10)
    expect(page).to have_selector('#notification .message.notice', wait: 5)
    expect(page).to have_content('successfully updated')

    # Verify disabled cells were set correctly
    bracket.reload
    disabled_positions.each do |pos|
      bracketer = bracket.bracketers.pos(pos[:row], pos[:col]).first
      expect(bracketer).to be_present
      expect(bracketer.disabled).to be true
    end

    # Verify custom text cells were set correctly
    custom_text_positions.each do |pos|
      bracketer = bracket.bracketers.pos(pos[:row], pos[:col]).first
      expect(bracketer).to be_present
      expect(bracketer.custom_text).to eq(pos[:text])
    end

    # Visit bracket view to verify display
    visit bracket_path(bracket)
    expect(page).to have_content(bracket.name)
  end

  private

  def extract_cell_position(select)
    name_attr = select['name']
    return unless name_attr =~ /cell\[(\d+)\]\[(\d+)\]/

    { row: Regexp.last_match(1).to_i, col: Regexp.last_match(2).to_i }
  end
end
