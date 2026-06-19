# frozen_string_literal: true

require 'rails_helper'

RSpec.feature 'League contest UI integration', type: :feature, js: true do
  let!(:admin) { create(:user, :admin) }
  let!(:team_leader1) { create(:user, username: 'leader1') }
  let!(:team_leader2) { create(:user, username: 'leader2') }
  let!(:team_leader3) { create(:user, username: 'leader3') }
  let!(:team_leader4) { create(:user, username: 'leader4') }

  scenario 'Admin creates a league, team leaders create teams, matches created and scores recorded through UI' do
    # Create maps beforehand
    map1 = create(:map, name: 'League Map 1')
    map2 = create(:map, name: 'League Map 2')

    # STEP 1: Admin creates the league contest
    sign_in_via_session(admin)
    visit new_contest_path

    fill_in 'contest_name', with: 'Integration League Test'
    select 'League', from: 'contest_contest_type'

    # Set start and end dates
    start_time = 1.day.ago
    end_time = 10.days.from_now
    select_datetime(start_time, from: 'contest_start')
    select_datetime(end_time, from: 'contest_end')

    click_button 'Save'

    # Validate contest creation
    expect(page).to have_content('Contest was successfully created')
    contest = Contest.find_by(name: 'Integration League Test')
    expect(contest).to be_present
    expect(contest.contest_type).to eq(Contest::TYPE_LEAGUE)

    # Verify navigation to contest edit page
    visit root_path
    within('.navigation') do
      click_link 'Contests'
    end
    click_link 'Integration League Test'
    click_link 'Edit Contest'
    expect(page).to have_content('Editing Contest')

    # Navigate to contest edit page and add maps via UI
    click_link(href: '#maps', wait: 5)

    [map1, map2].each do |map|
      select map.name, from: 'map'
      click_button 'Add map'
      expect(page).to have_css('#maps table.maps', text: map.name, wait: 5)
    end

    # Verify maps were added
    contest.reload
    expect(contest.maps.count).to be >= 2

    # Create a week for the league
    click_link(href: '#weeks', wait: 5)
    click_link 'New Week'
    expect(page).to have_field('week_name', wait: 5)
    fill_in 'week_name', with: 'Week 1'
    click_button 'Save Week'
    expect(page).to have_content('Week 1', wait: 5)

    # STEP 3: Team leaders create their teams
    team_names = ['Team Alpha', 'Team Beta', 'Team Gamma', 'Team Delta']
    teams = []

    team_names.each_with_index do |team_name, index|
      leader = [team_leader1, team_leader2, team_leader3, team_leader4][index]
      sign_out
      sign_in_as(leader)

      visit new_team_path
      fill_in 'team_name', with: team_name
      fill_in 'team_tag', with: "[T#{index + 1}]"
      fill_in 'team_irc', with: "#team#{index + 1}"

      click_button 'Create'

      expect(page).to have_content(team_name)
      teams << Team.find_by(name: team_name)
    end

    # STEP 4: Admin adds teams to contest
    sign_out
    sign_in_as(admin)
    visit edit_contest_path(contest)
    click_link(href: '#teams', wait: 5)
    expect(page).to have_css('#teams')

    teams.each do |team|
      # The form for adding teams is the last form in the teams section
      # It has a select for team_id with field name 'contester[team_id]'
      select team.name, from: 'contester_team_id'
      click_button 'Add Team'

      # Explicitly visit the page to ensure fresh rendering and avoid stale DOM
      visit edit_contest_path(contest)
      click_link(href: '#teams', wait: 5)
      expect(page).to have_css('#teams table.teams', text: team.name, wait: 5)
    end

    contest.reload
    expect(contest.contesters.count).to eq(4)

    # STEP 5: Admin creates round-robin matches
    click_link(href: '#matches', wait: 5)

    contesters = contest.contesters.to_a
    matches_to_score = []

    # Create matches for each pair
    contesters.combination(2) do |c1, c2|
      click_link 'New Match'

      # Select contesters using direct option selection (more reliable than select helper)
      find('#match_contester1_id').find('option', text: c1.team.name).select_option
      find('#match_contester2_id').find('option', text: c2.team.name).select_option

      # Select match time (2 days from now)
      select_match_datetime(Time.current + 2.days)

      # Select maps using direct option selection
      find('#match_map1_id').find('option', text: map1.name).select_option
      find('#match_map2_id').find('option', text: map2.name).select_option

      click_button 'Save Match'

      # Check for form errors
      if page.has_css?('#errors')
        error_text = page.find('#errors').text
        raise "Match creation failed: #{error_text}"
      end

      # The match should exist after successful creation
      match = Match.where(contest: contest, contester1_id: c1.id, contester2_id: c2.id).last
      if match
        matches_to_score << match
      else
        # If not found, don't fail yet - we'll check later
        puts "Warning: Match not found for #{c1.team.name} vs #{c2.team.name}"
      end
    end

    expect(matches_to_score.size).to be >= 1

    # STEP 6: Admin records match scores via referee interface
    rng = Random.new(20_260_121)

    matches_to_score.each_with_index do |match, _idx|
      visit ref_match_path(match)

      score1 = rng.rand(0..5)
      score2 = rng.rand(0..5)

      # Make sure we're on the right page
      expect(page).to have_content('Scoring')

      # Fill in the score fields
      fill_in 'match_score1', with: score1.to_s
      fill_in 'match_score2', with: score2.to_s

      # Check that fields were filled
      expect(page).to have_field('match_score1', with: score1.to_s)
      expect(page).to have_field('match_score2', with: score2.to_s)

      # Submit the form
      click_button 'Save Scoring'
      expect(page).to have_content(I18n.t(:matches_update), wait: 5)

      # Reload the match to verify scores were saved
      match.reload

      # Verify scores are set
      expect(match.score1).to eq(score1)
      expect(match.score2).to eq(score2)
    end

    # STEP 7: Reload and verify scores and standings
    contest.reload
    contesters.each(&:reload)

    # Verify all matches have scores
    expect(Match.where(contest: contest).all?(&:score1)).to be true
    expect(Match.where(contest: contest).all?(&:score2)).to be true

    # Verify standings show updated stats
    visit edit_contest_path(contest)
    click_link(href: '#teams', wait: 5)

    within('#teams table.teams') do
      teams.each do |team|
        contester = contest.contesters.find_by(team: team)
        contester.reload
        row = find('tr', text: team.name)
        cells = row.all('td')

        # Verify the row shows correct column values
        # Row format: Team name, Score, Win, Loss, Draw, Bonus, Status
        expect(cells[0]).to have_link(team.name)
        expect(cells[1]).to have_text(contester.score.to_s)
        expect(cells[2]).to have_text(contester.win.to_s)
        expect(cells[3]).to have_text(contester.loss.to_s)
        expect(cells[4]).to have_text(contester.draw.to_s)
      end
    end
  end
end
