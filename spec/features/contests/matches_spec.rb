# frozen_string_literal: true

require 'rails_helper'

RSpec.feature 'Matches management', :js, type: :feature do
  let!(:admin) { create(:user, :admin) }
  let!(:contest) { create(:contest) }
  let!(:home_map) { create(:map) }
  let!(:away_map) { create(:map) }
  let!(:reserve_home_map) { create(:map) }
  let!(:reserve_away_map) { create(:map) }
  let!(:week) { create(:week, contest: contest, map1: home_map, map2: away_map) }
  let!(:home_team) { create(:team) }
  let!(:away_team) { create(:team) }
  let!(:alternate_team) { create(:team) }
  let!(:home_contester) { create(:contester, team: home_team, contest: contest) }
  let!(:away_contester) { create(:contester, team: away_team, contest: contest) }
  let!(:alternate_contester) { create(:contester, team: alternate_team, contest: contest) }
  let!(:referee) { create(:user, :ref) }
  let!(:server) { create(:server) }
  let!(:match) do
    create(
      :match,
      contest: contest,
      contester1: home_contester,
      contester2: away_contester,
      map1: home_map,
      map2: away_map,
      week: week,
      referee: referee,
      server: server
    )
  end

  before do
    # sign in as admin to have full permissions
    contest.maps << [home_map, away_map, reserve_home_map, reserve_away_map]
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
    click_link(href: '#matches')

    expect(page).to have_css('#matches table.matches')
    within('#matches') do
      expect(page).to have_text(contester1_opt[:text])
      expect(page).to have_text(contester2_opt[:text])
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
    expect(page).to have_text(contester1_opt[:text])
    expect(page).to have_text(contester2_opt[:text])
    expect(page).to have_text(map1_opt[:text])
    expect(page).to have_text(map2_opt[:text])
    m = Match.find(match.id)
    expect(m.week_id).to eq(week_opt[:id])
  end

  scenario 'Delete a match from the view with JS', :aggregate_failures do
    # Create a match first
    visit new_match_path(id: contest.id)

    # Create via factory
    expect(Match.where(contest: contest).count).to eq(1)

    visit edit_contest_path(contest)
    click_link(href: '#matches')
    expect(page).to have_css('#matches table.matches')
    expect(page).to have_text(match.contester1.team.name)

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

    expect(page).to have_text(I18n.t('flash.actions.destroy.notice', resource_name: Match.model_name.human))
    expect(page).to have_current_path(edit_contest_path(contest))
  end

  scenario 'Referee a match from the match view with JS', :aggregate_failures do # Create a server for the match
    # Sign in as referee
    sign_out
    sign_in_as(referee)

    visit ref_match_path(match)
    expect(page).to have_text('Referee Admin')
    expect(page).to have_text('Scoring')

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
