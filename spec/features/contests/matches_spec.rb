# frozen_string_literal: true

require 'rails_helper'

RSpec.feature 'Matches management', type: :feature, js: true do
  let!(:admin) { create(:user, :admin) }
  let!(:contest) { create(:contest) }
  let!(:map1) { create(:map) }
  let!(:map2) { create(:map) }
  let!(:map3) { create(:map) }
  let!(:map4) { create(:map) }
  let!(:week) { create(:week, contest: contest, map1: map1, map2: map2) }
  let!(:team1) { create(:team) }
  let!(:team2) { create(:team) }
  let!(:team3) { create(:team) }
  let!(:contester1) { create(:contester, team: team1, contest: contest) }
  let!(:contester2) { create(:contester, team: team2, contest: contest) }
  let!(:contester3) { create(:contester, team: team3, contest: contest) }
  let!(:referee) { create(:user, :ref) }
  let!(:server) { create(:server) }
  let!(:match) do
    create(:match, contest: contest, contester1: contester1, contester2: contester2, map1: map1, map2: map2,
                   week: week, referee: referee, server: server)
  end

  before do
    # sign in as admin to have full permissions
    contest.maps << [map1, map2, map3, map4]
    sign_in_as(admin)
  end

  scenario 'Create a match from the new match view with JS', :aggregate_failures do
    visit new_match_path(id: contest.id)

    contester1_opt = select_first_option('match_contester1_id')
    contester2_opt = select_last_option('match_contester2_id')
    select_datetime_by_value(Time.current + 2.days, 'match_match_time')
    select_first_option('match_map1_id')
    select_last_option('match_map2_id')

    click_button 'Save Match'

    expect(page).to have_current_path(/matches|contests/) # redirected to match or contest edit

    # Not necessary
    find("a[href='#matches']").click

    expect(page).to have_css('#matches table.matches')
    within('#matches') do
      expect(page).to have_content(contester1_opt[:text])
      expect(page).to have_content(contester2_opt[:text])
    end
  end

  scenario 'Update editable match attributes via the edit view with JS', :aggregate_failures do
    visit edit_match_path(match)

    # Update fields available on the edit form
    contester1_opt = select_first_option('match_contester1_id')
    contester2_opt = select_last_option('match_contester2_id')
    map1_opt = select_last_option('match_map1_id')
    map2_opt = select_last_option('match_map2_id')
    week_opt = select_last_option('match_week_id')
    select_datetime_by_value(Time.current + 3.days, 'match_match_time')

    click_button 'Save Match'

    expect(page).to have_current_path(match_path(match))
    expect(page).to have_content(contester1_opt[:text])
    expect(page).to have_content(contester2_opt[:text])
    expect(page).to have_content(map1_opt[:text])
    expect(page).to have_content(map2_opt[:text])
    m = Match.find(match.id)
    expect(m.week_id).to eq(week_opt[:id])
  end

  scenario 'Delete a match from the view with JS', :aggregate_failures do
    # Create a match first
    visit new_match_path(id: contest.id)

    # Create via factory
    expect(Match.where(contest: contest).count).to eq(1)

    visit edit_contest_path(contest)
    find("a[href='#matches']").click
    expect(page).to have_css('#matches table.matches')
    expect(page).to have_content(match.contester1.team.name)

    # Delete from the matches table action link for the created match row
    within('#matches') do
      # Row may be present but hidden by the tab widget; allow searching hidden nodes
      row = find('tr', text: match.contester1.team.name, visible: :all)
      within(row) do
        # Use Capybara's accept_confirm to handle the confirmation dialog
        accept_confirm do
          find("a[data-method='delete']").click
        end
      end
    end

    expect(page).to have_content(I18n.t('flash.actions.destroy.notice', resource_name: Match.model_name.human))
    expect(page).to have_current_path(edit_contest_path(contest))
  end

  scenario 'Referee a match from the match view with JS', :aggregate_failures do # Create a server for the match
    # Sign in as referee
    sign_out
    sign_in_as(referee)

    visit ref_match_path(match)
    expect(page).to have_content('Referee Admin')
    expect(page).to have_content('Scoring')

    # Select a server
    select(server.name, from: 'match_server_id')

    # Fill in scores
    fill_in 'match_score1', with: '16'
    fill_in 'match_score2', with: '14'

    # Fill in Player of the match (name)
    fill_in 'match_motm_name', with: 'Excellent Player'

    click_button 'Save Scoring'

    # Check for form errors
    raise "Found errors: #{page.find('div.errors-block').text}" if page.has_css?('div.errors-block')

    # Verify the match now has scores
    match.reload
    expect(match.score1).to eq(16)
    expect(match.score2).to eq(14)
  end
end
