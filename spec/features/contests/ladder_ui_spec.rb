# frozen_string_literal: true

require 'rails_helper'

RSpec.feature 'Ladder contest UI integration', type: :feature, js: true do
  let!(:admin) { create(:user, :admin) }
  let!(:maps) { create_list(:map, 3) }
  let(:start_time) { 1.day.ago }
  let(:end_time) { 30.days.from_now }

  def create_open_ladder(name:)
    contest = create(:contest,
                     name: name,
                     contest_type: Contest::TYPE_LADDER,
                     status: Contest::STATUS_OPEN,
                     start: start_time,
                     end: end_time)
    contest.maps << maps
    contest.reload
    contest
  end

  def join_ladder_as(team:, leader:, contest:)
    sign_out
    sign_in_as(leader)

    visit contest_path(contest)
    expect(page).to have_select('contester_team_id', with_options: [team.name])
    select team.name, from: 'contester_team_id'
    page.execute_script("document.querySelector('form.square').submit()")

    expect(page).to(
      have_content(I18n.t(:contests_join), wait: 5)
        .or(have_content('You are not allowed to visit the page', wait: 5))
    )

    visit contest_path(contest)
    expect(page).to have_css('table.contest', text: team.name)
  end

  def submit_form_without_turbo(action:, commit_value:)
    page.execute_script(<<~JS)
      const form = document.querySelector("form[action='#{action}']");
      const commit = document.createElement('input');
      commit.type = 'hidden';
      commit.name = 'commit';
      commit.value = #{commit_value.to_json};
      form.appendChild(commit);
      form.submit();
    JS
  end

  scenario 'Admin creates a ladder contest through the UI' do
    sign_in_as(admin)
    visit new_contest_path

    fill_in 'contest_name', with: 'Integration Ladder Test'
    select 'Ladder', from: 'contest_contest_type'
    select 'In Progress (signups open)', from: 'contest_status'

    select_datetime(start_time, from: 'contest_start')
    select_datetime(end_time, from: 'contest_end')

    click_button 'Save'

    expect(page).to have_content('Contest was successfully created')
    contest = Contest.find_by(name: 'Integration Ladder Test')
    expect(contest).to be_present
    expect(contest.contest_type).to eq(Contest::TYPE_LADDER)
    expect(page).to have_current_path(contest_path(contest))
  end

  scenario 'Team leaders join a ladder contest through the UI' do
    contest = create_open_ladder(name: 'Ladder Join Test')
    leaders = create_list(:user, 4)
    teams = leaders.map { |leader| create(:team, :with_leader, founder: leader) }

    teams.each_with_index do |team, index|
      join_ladder_as(team: team, leader: leaders[index], contest: contest)
    end

    contest.reload
    expect(contest.contesters.count).to eq(4)

    visit contest_path(contest)
    expect(page).to have_content('Ladder')
    expect(page).to have_css('table.contest')

    teams.each do |team|
      expect(page).to have_content(team.name)
    end
  end

  scenario 'Team leaders create, accept, and decline ladder challenges through the UI' do
    map1 = maps.first
    contest = create_open_ladder(name: 'Ladder Challenge Test')
    leaders = create_list(:user, 4)
    teams = leaders.map { |leader| create(:team, :with_leader, founder: leader) }

    teams.each_with_index do |team, index|
      join_ladder_as(team: team, leader: leaders[index], contest: contest)
    end

    contesters = teams.map { |team| contest.contesters.find_by!(team: team) }
    base_time = Time.current + 2.days

    sign_out
    sign_in_as(leaders[0])
    visit contest_path(contest)
    within('table.contest') do
      row = find('tr', text: teams[1].name)
      row.find('a', text: 'C').click
    end

    select_datetime(base_time, from: 'challenge_match_time')
    select map1.name, from: 'challenge_map1_id'
    fill_in 'challenge_details', with: "Challenge from #{teams[0].name}"
    click_button 'Create'
    expect(page).to have_content(I18n.t(:challenges_create))

    accepted_challenge = Challenge.where(contester1: contesters[0], contester2: contesters[1]).last
    expect(accepted_challenge).to be_present

    sign_out
    sign_in_as(leaders[1])
    visit challenge_path(accepted_challenge)
    select map1.name, from: 'challenge_map2_id'
    submit_form_without_turbo(action: challenge_path(accepted_challenge), commit_value: 'Accept')
    expect(page).to have_content('Accepted', wait: 5)
    expect(page).to have_link('Accepted')

    sign_out
    sign_in_as(leaders[2])
    visit contest_path(contest)
    within('table.contest') do
      row = find('tr', text: teams[3].name)
      row.find('a', text: 'C').click
    end

    select_datetime(base_time + 3.hours, from: 'challenge_match_time')
    select map1.name, from: 'challenge_map1_id'
    fill_in 'challenge_details', with: "Challenge from #{teams[2].name}"
    click_button 'Create'
    expect(page).to have_content(I18n.t(:challenges_create))

    declined_challenge = Challenge.where(contester1: contesters[2], contester2: contesters[3]).last
    expect(declined_challenge).to be_present

    sign_out
    sign_in_as(leaders[3])
    visit challenge_path(declined_challenge)
    select map1.name, from: 'challenge_map2_id'
    submit_form_without_turbo(action: challenge_path(declined_challenge), commit_value: 'Decline')
    expect(page).to have_content('Declined', wait: 5)
    expect(page).not_to have_content('Match details')
  end

  scenario 'Admin scores ladder matches through the UI and standings update' do
    contest = create_open_ladder(name: 'Ladder Scoring Test')
    teams = create_list(:team, 4, :with_leader)

    teams.each_with_index do |team, index|
      create(:contester, contest: contest, team: team, score: index + 1)
    end

    contester1 = contest.contesters.find_by!(team: teams[0])
    contester2 = contest.contesters.find_by!(team: teams[1])
    match = create(:match,
                   contest: contest,
                   contester1: contester1,
                   contester2: contester2,
                   map1: maps.first,
                   map2: maps.second,
                   match_time: 1.hour.ago)

    sign_in_as(admin)
    visit ref_match_path(match)
    expect(page).to have_content('Scoring')

    fill_in 'match_score1', with: '4'
    fill_in 'match_score2', with: '2'
    click_button 'Save Scoring'
    expect(page).to have_content(I18n.t(:matches_update), wait: 5)

    match.reload
    expect(match.score1).to eq(4)
    expect(match.score2).to eq(2)

    visit contest_path(contest)
    expect(page).to have_css('table.contest')

    within('table.contest tbody') do
      row = find('tr', text: teams[0].name)
      cells = row.all('td')
      expect(cells[3]).to have_link(teams[0].name)
      expect(cells[5]).to have_text('1')
      expect(cells[6]).to have_text('0')
      expect(cells[7]).to have_text('0')
    end

    within('#results') do
      expect(page).to have_content('Matches Played')
      expect(page).to have_content(teams[0].name)
      expect(page).to have_content(teams[1].name)
    end
  end

  scenario 'Ladder contest displays rankings and match history correctly' do
    contest = create(:contest, :with_maps,
                     name: 'Ladder History Test',
                     contest_type: Contest::TYPE_LADDER,
                     status: Contest::STATUS_OPEN,
                     start: start_time,
                     end: end_time,
                     maps_count: 3)

    teams = create_list(:team, 6, :with_leader)
    teams.each_with_index do |team, index|
      create(:contester, contest: contest, team: team, score: index + 1)
    end

    rng = Random.new(20_260_614)
    contesters = contest.contesters.includes(:team).to_a

    12.times do |index|
      contester1, contester2 = contesters.sample(2, random: rng)

      create(:match,
             contest: contest,
             contester1: contester1,
             contester2: contester2,
             map1: maps.sample(random: rng),
             map2: maps.sample(random: rng),
             match_time: Time.current - (index * 2).hours,
             score1: rng.rand(1..4),
             score2: rng.rand(1..4))
    end

    visit contest_path(contest)
    expect(page).to have_css('table.contest')

    within('table.contest tbody') do
      teams.each do |team|
        contester = contest.contesters.find_by!(team: team)

        row = find('tr', text: team.name)
        cells = row.all('td')

        expect(cells[0]).to have_text(/\d+/)
        expect(cells[3]).to have_link(team.name)
        expect(cells[5].text).to eq(contester.win.to_s)
        expect(cells[6].text).to eq(contester.loss.to_s)
        expect(cells[7].text).to eq(contester.draw.to_s)
        expect(contester.win).to be >= 0
        expect(contester.loss).to be >= 0
        expect(contester.draw).to be >= 0
      end
    end

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
