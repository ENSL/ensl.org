require 'rails_helper'

RSpec.feature 'Teams management', type: :feature, js: true do
  let!(:user) { create(:user) }
  let!(:admin) { create(:user, :admin) }

  scenario 'User creates a team' do
    sign_in_as(user)
    visit new_team_path

    fill_in 'team_name', with: 'Spec Team'
    fill_in 'team_tag', with: '[SPC]'
    fill_in 'team_irc', with: '#specteam'
    click_button 'Create'

    expect(page).to have_content('Spec Team')
    expect(Team.where(name: 'Spec Team').exists?).to be true
  end

  scenario 'User requests to join an existing team' do
    team = create(:team)
    sign_in_as(user)
    visit team_path(team)

    expect(page).to have_button('Request To Join')
    click_button 'Request To Join'
    expect(page).to have_current_path(team_path(team))

    expect(Teamer.where(user: user, team: team).joining.exists?).to be true
  end

  scenario 'Leader can edit their team' do
    team = create(:team, founder: user)
    sign_in_as(user)
    visit edit_team_path(team)

    new_name = "#{team.name} Updated"
    find("a[href='#details']").click
    within('#details') do
      fill_in 'team_name', with: new_name
      click_button 'Update'
    end

    expect(team.reload.name).to eq(new_name)
    visit edit_team_path(team)
    expect(page).to have_content(new_name)
  end

  scenario 'Admin soft-deletes a team with matches and recovers it' do
    team = create(:team)
    contest = create(:contest)
    cont1 = create(:contester, contest: contest, team: team)
    cont2 = create(:contester, contest: contest)
    create(:match, contest: contest, contester1: cont1, contester2: cont2)

    sign_in_as(admin)
    visit teams_path

    within('table') do
      row = find('tr', text: team.name)
      link = row.find("a[data-method='delete']", match: :first)
      if link[:'data-confirm'].present?
        accept_confirm { link.click }
      else
        link.click
      end
    end

    expect(team.reload.active).to be false

    visit teams_path
    within('table') do
      row = find('tr', text: team.name)
      row.find("a[href='#{recover_team_path(team)}']").click
    end

    expect(team.reload.active).to be true
  end

  scenario 'Leader accepts joiners, updates role/comment and can kick members' do
    team = create(:team, founder: user)
    joiner = create(:user)
    member = create(:teamer, team: team, user: joiner)

    sign_in_as(user)
    visit edit_team_path(team)
    # show members tab (tabs are JS-controlled)
    find("a[href='#members']").click

    within('#members') do
      # Promote joiner to member and set a comment
      find("input[name='comment[#{member.id}]']").set('Good player')
      find("select[name='rank[#{member.id}]']").find(:option, 'Member').select_option

      click_button 'Update'
    end

    visit edit_team_path(team)
    member.reload
    expect(member.rank).to eq(Teamer::RANK_MEMBER)
    expect(member.comment).to eq('Good player')
    expect(member.user.team).to eq(team)

    visit edit_team_path(team)
    find("a[href='#members']").click
    within('#members') do
      row = find('tr', text: member.user.username)
      link = row.find('a.button.tiny', match: :first)
      if link[:'data-confirm'].present?
        accept_confirm { link.click }
      else
        link.click
      end
    end

    visit edit_team_path(team)
    member.reload
    expect(member.rank).to eq(Teamer::RANK_REMOVED)
  end

  scenario 'Admin can manage any team members and edit team details' do
    other = create(:user)
    team = create(:team, founder: other)
    joiner = create(:user)
    member = create(:teamer, team: team, user: joiner)

    sign_in_as(admin)
    visit edit_team_path(team)

    within('#details') do
      fill_in 'team_name', with: 'Admin Edited'
      click_button 'Update'
    end

    visit edit_team_path(team)
    expect(team.reload.name).to eq('Admin Edited')

    # Admin accepts the joiner and sets comment
    find("a[href='#members']").click
    within('#members') do
      find("input[name='comment[#{member.id}]']").set('Invited')
      find("select[name='rank[#{member.id}]']").find(:option, 'Member').select_option
      click_button 'Update'
    end

    visit edit_team_path(team)
    member.reload
    expect(member.rank).to eq(Teamer::RANK_MEMBER)
    expect(member.comment).to eq('Invited')
  end
end
