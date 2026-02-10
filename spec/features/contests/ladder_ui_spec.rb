require 'rails_helper'

RSpec.feature 'Ladder contest UI integration', type: :feature, js: true do
  let!(:admin) { create(:user, :admin) }
  let!(:maps) { create_list(:map, 3) }

  scenario 'Admin creates a ladder, teams join, and ladder standings are calculated from match results' do
    map1 = maps.first

    # STEP 1: Admin creates the ladder contest
    sign_in_via_session(admin)
    visit new_contest_path

    fill_in 'contest_name', with: 'Integration Ladder Test'
    select 'Ladder', from: 'contest_contest_type'
    select 'In Progress (signups open)', from: 'contest_status'

    start_time = 1.day.ago
    end_time = 30.days.from_now
    select_datetime(start_time, from: 'contest_start')
    select_datetime(end_time, from: 'contest_end')

    click_button 'Save'

    # Validate contest creation
    expect(page).to have_content('Contest was successfully created')
    contest = Contest.find_by(name: 'Integration Ladder Test')
    expect(contest).to be_present
    expect(contest.contest_type).to eq(Contest::TYPE_LADDER)
    contest.update!(status: Contest::STATUS_OPEN)

    # Add maps via factories since UI map addition is tested elsewhere
    contest.maps << maps
    contest.reload
    expect(contest.maps).to include(map1)

    # STEP 2: Players and teams via factories. UI is tested elsewhere.
    teams = create_list(:team, 4, :with_leader)
    player_list = teams.map { |team| team.teamers.leaders.first.user }

    # STEP 3: Teams join the ladder contest themselves via UI
    teams.each_with_index do |team, index|
      sign_out
      sign_in_via_session(player_list[index])

      visit contest_path(contest)
      expect(page).to have_select('contester_team_id', with_options: [team.name])
      select team.name, from: 'contester_team_id'
      click_button 'Join Contest'

      raise "Join forbidden for team #{team.name}" if page.has_content?('You are not allowed to visit the page')

      expect(Contester.find_by(contest: contest, team: team)).to be_present
    end

    contest.reload
    expect(contest.contesters.count).to eq(4)

    # STEP 4: Verify initial ladder rendering (all at same level with score 0)
    visit contest_path(contest)
    expect(page).to have_content('Ladder')

    # Check for the ladder table
    expect(page).to have_css('table.contest')

    # All teams should be visible in the ladder
    teams.each do |team|
      expect(page).to have_content(team.name)
    end

    # STEP 5: Teams create challenges via UI, and opponents accept or decline
    contesters = teams.map { |team| contest.contesters.find_by(team: team) }
    challenges = []
    matches = []

    base_time = Time.current + 2.days

    # Pairs of contesters to create challenges between
    pairs = [[0, 1], [1, 2], [2, 3], [3, 0], [0, 2], [1, 3]]
    pairs.each_with_index do |pair, index|
      cont1 = contesters[pair[0]]
      cont2 = contesters[pair[1]]

      sign_out
      sign_in_via_session(player_list[pair[0]])

      visit contest_path(contest)
      within('table.contest') do
        row = find('tr', text: cont2.team.name)
        row.find('a', text: 'C').click
      end

      # Create challenge via UI
      select_datetime(base_time + (index * 3).hours, from: 'challenge_match_time')
      select map1.name, from: 'challenge_map1_id'
      fill_in 'challenge_details', with: "Challenge from #{cont1.team.name}"
      click_button 'Create'
      expect(page).to have_content(I18n.t(:challenges_create))

      challenge = Challenge.where(contester1: cont1, contester2: cont2).last
      expect(challenge).to be_present
      challenges << challenge

      sign_out
      sign_in_via_session(player_list[pair[1]])
      visit challenge_path(challenge)

      if index < 5
        # Select a map before accepting (required for match creation)
        select map1.name, from: 'challenge_map2_id'
        click_button 'Accept', wait: 5
        # Give time for async request to complete
        sleep 1

        # Verify the challenge was accepted in the database
        challenge.reload
        expect(challenge.status).to eq(Challenge::STATUS_ACCEPTED)
        expect(challenge.match).to be_present

        matches << challenge.match
      else
        click_button 'Decline', wait: 5
        sleep 1
        challenge.reload
        expect(challenge.status).to eq(Challenge::STATUS_DECLINED)
      end
    end

    expect(matches.size).to eq(5)

    # STEP 6: Admin records match scores via referee interface
    sign_out
    sign_in_via_session(admin)
    rng = Random.new(20_260_121)

    matches.each do |match|
      visit ref_match_path(match)

      score1 = rng.rand(1..5)
      score2 = rng.rand(1..5)

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
      expect(match.score1).to eq(score1)
      expect(match.score2).to eq(score2)
    end

    # STEP 7: Verify ladder standings have been updated based on match results
    visit contest_path(contest)
    expect(page).to have_css('table.contest')

    # Reload contesters to get updated scores
    contest.contesters.each(&:reload)

    # Verify the ladder table shows updated stats
    within('table.contest tbody') do
      teams.each do |team|
        row = find('tr', text: team.name)
        cells = row.all('td')

        contester = contest.contesters.find_by(team: team)
        expected_stats = contester.stats_from_matches

        # Ladder row format: Rank, Movement icon, Flag, Team name (link), Trophy, Win, Loss, Draw
        expect(cells[0]).to have_text(/\d+/) # Rank number
        expect(cells[3]).to have_link(team.name) # Team name as link
        expect(cells[5]).to have_text(expected_stats[:win].to_s)
        expect(cells[6]).to have_text(expected_stats[:loss].to_s)
        expect(cells[7]).to have_text(expected_stats[:draw].to_s)

        expect(contester.win).to eq(expected_stats[:win])
        expect(contester.loss).to eq(expected_stats[:loss])
        expect(contester.draw).to eq(expected_stats[:draw])
      end
    end
  end

  scenario 'Ladder contest displays rankings and match history correctly' do
    # Setup: Create ladder contest with teams, maps, and scored matches via factory
    contest = create(:contest, :with_maps, :with_teams, :with_scored_matches,
                     name: 'Ladder History Test',
                     contest_type: Contest::TYPE_LADDER,
                     status: Contest::STATUS_OPEN,
                     start: 1.day.ago,
                     end: 30.days.from_now,
                     maps_count: 3,
                     teams_count: 10,
                     matches_count: 50)

    contesters = contest.contesters.to_a
    teams = contesters.map(&:team)

    # Verify the ladder renders correctly as an unauthenticated user
    visit contest_path(contest)
    expect(page).to have_css('table.contest')

    # Verify the ladder table shows correct data for all teams
    within('table.contest tbody') do
      contesters.each do |contester|
        contester.reload
        team = contester.team

        row = find('tr', text: team.name)
        cells = row.all('td')

        # Ladder row format: Rank, Movement icon, Flag, Team name (link), Trophy, Win, Loss, Draw
        expect(cells[0]).to have_text(/\d+/) # Rank number
        expect(cells[3]).to have_link(team.name) # Team name as link

        # Verify win/loss/draw values match database
        expect(cells[5].text).to eq(contester.win.to_s)
        expect(cells[6].text).to eq(contester.loss.to_s)
        expect(cells[7].text).to eq(contester.draw.to_s)

        # Sanity check: all stats should be >= 0
        expect(contester.win).to be >= 0
        expect(contester.loss).to be >= 0
        expect(contester.draw).to be >= 0
      end
    end

    # Verify all teams and matches visible
    within('table.contest tbody') do
      teams.each do |team|
        expect(page).to have_content(team.name)
      end
    end

    within('#results') do
      expect(page).to have_content('Matches Played')
    end
  end
end
