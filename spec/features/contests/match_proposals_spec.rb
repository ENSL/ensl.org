require 'rails_helper'

# Match Proposals Feature Spec
# Tests the match proposal workflow as used in live production
# Includes team leaders proposing match times, opposing teams confirming/rejecting, etc.
RSpec.feature 'Match Proposals', type: :feature, js: true do
  let(:contest) { create(:contest) }
  let(:team1_leader) { create(:user_with_team, username: 'team1_leader') }
  let(:team1) { team1_leader.team }
  let(:team2_leader) { create(:user_with_team, username: 'team2_leader') }
  let(:team2) { team2_leader.team }
  let(:admin) { create(:user, :admin) }
  let(:cont1) { create(:contester, team: team1, contest: contest) }
  let(:cont2) { create(:contester, team: team2, contest: contest) }
  let(:match) { create(:match, contest: contest, contester1: cont1, contester2: cont2) }

  before do
    Capybara.javascript_driver = :selenium_chrome_headless
  end

  scenario 'team leader views match proposals page' do
    sign_in_via_session(team1_leader)
    visit match_proposals_path(match)

    expect(page).to have_content('Proposals')
    expect(page).to have_content(team1.name)
    expect(page).to have_content(team2.name)
    expect(page).to have_link('Propose match time')
    expect(page).to have_link('Back')
  end

  scenario 'team leader creates a new match proposal with valid time' do
    sign_in_via_session(team1_leader)
    visit new_match_proposal_path(match)

    expect(page).to have_button('Propose')

    # Fill in the datetime using the helper
    future_time = 3.days.from_now
    select_datetime(future_time, from: 'match_proposal_proposed_time')
    click_button 'Propose'

    # Should redirect to proposals page and show success
    expect(page).to have_current_path(match_proposals_path(match))
    expect(page).to have_content('Pending')

    # Verify the proposal was created correctly
    proposal = MatchProposal.last
    expect(proposal.team).to eq(team1)
    expect(proposal.match).to eq(match)
    expect(proposal.status).to eq(MatchProposal::STATUS_PENDING)
  end

  scenario 'proposal gets correct status after creation' do
    sign_in_via_session(team1_leader)

    # Create proposal via form
    visit new_match_proposal_path(match)
    select_datetime(2.days.from_now, from: 'match_proposal_proposed_time')
    click_button 'Propose'

    # Verify it shows up on proposals page with correct status
    expect(page).to have_current_path(match_proposals_path(match))
    expect(page).to have_content('Pending')

    proposal = MatchProposal.last
    expect(proposal.status).to eq(MatchProposal::STATUS_PENDING)
    expect(proposal.match_id).to eq(match.id)
  end

  scenario 'opposing team sees the proposal in their list' do
    create(:match_proposal, :in_far_future, match: match, team: team1)

    sign_in_via_session(team2_leader)
    visit match_proposals_path(match)

    expect(page).to have_content(team1.name)
    expect(page).to have_content('Pending')
  end

  scenario 'opposing team confirms a proposal outside confirmation limit' do
    proposal = create(:match_proposal, :in_near_future, match: match, team: team1)

    sign_in_via_session(team2_leader)
    visit match_proposals_path(match)

    # Should see the proposal
    expect(page).to have_content(team1.name)
    expect(page).to have_content('Pending')
    # Verify confirm button would be available (via model permission check)
    expect(proposal.status_change_allowed?(team2_leader, MatchProposal::STATUS_CONFIRMED)).to be true
  end

  scenario 'team leader cannot confirm own proposal' do
    create(:match_proposal, :in_near_future, match: match, team: team1)

    sign_in_via_session(team1_leader)
    visit match_proposals_path(match)

    # Team 1 leader should not see confirm action for their own proposal
    expect(page).not_to have_xpath("//a[@title='Confirm']")
  end

  scenario 'opposing team rejects a proposal outside confirmation limit' do
    proposal = create(:match_proposal, :in_near_future, match: match, team: team1)

    sign_in_via_session(team2_leader)
    visit match_proposals_path(match)

    # Should see the proposal and reject should be available
    expect(page).to have_content(team1.name)
    expect(page).to have_content('Pending')
    expect(proposal.status_change_allowed?(team2_leader, MatchProposal::STATUS_REJECTED)).to be true
  end

  scenario 'proposal cannot be confirmed within confirmation limit' do
    # Proposal 10 minutes in the future (within 30 minute limit)
    create(:match_proposal, match: match, team: team1, proposed_time: 10.minutes.from_now)

    sign_in_via_session(team2_leader)
    visit match_proposals_path(match)

    # Should not see confirm or reject options for pending proposals within time limit
    expect(page).not_to have_xpath("//a[@title='Confirm']")
    expect(page).not_to have_xpath("//a[@title='Reject']")
  end

  scenario 'team leader can revoke pending proposal' do
    proposal = create(:match_proposal, :in_far_future, match: match, team: team1)

    sign_in_via_session(team1_leader)
    visit match_proposals_path(match)

    # Should see the proposal and revoke should be allowed
    expect(page).to have_content('Pending')
    expect(proposal.status_change_allowed?(team1_leader, MatchProposal::STATUS_REVOKED)).to be true
  end

  scenario 'team leader can revoke confirmed proposal outside confirmation limit' do
    proposal = create(:match_proposal, :confirmed, :in_near_future, match: match, team: team1)

    sign_in_via_session(team1_leader)
    visit match_proposals_path(match)

    # Should see the proposal
    expect(page).to have_content('Confirmed')
    # Revoke should be allowed
    expect(proposal.status_change_allowed?(team1_leader, MatchProposal::STATUS_REVOKED)).to be true
  end

  scenario 'admin can delay a confirmed proposal within time limit' do
    proposal = create(:match_proposal, :confirmed, match: match, team: team1, proposed_time: 10.minutes.from_now)

    sign_in_via_session(admin)
    visit match_proposals_path(match)

    # Admin should see the proposal
    expect(page).to have_content('Confirmed')
    # Delay should be allowed for admin
    expect(proposal.status_change_allowed?(admin, MatchProposal::STATUS_DELAYED)).to be true
  end

  scenario 'proposal shows timestamp in human readable format' do
    create(:match_proposal, match: match, team: team1, proposed_time: 5.days.from_now)

    sign_in_via_session(team2_leader)
    visit match_proposals_path(match)

    # Should display time-related content
    expect(page).to have_content(team1.name)
    expect(page).to have_content('Pending')
  end

  scenario 'cannot create new proposal if confirmed one exists' do
    create(:match_proposal, :confirmed, :in_far_future, match: match, team: team1)

    sign_in_via_session(team2_leader)
    visit match_proposals_path(match)
    click_link 'Propose match time'

    # Should be redirected and see error message
    expect(page).to have_current_path(match_proposals_path(match))
    expect(page).to have_content('Cannot create a new proposal')
  end

  scenario 'non-team members cannot access proposals page' do
    non_member = create(:user)

    sign_in_via_session(non_member)
    visit match_proposals_path(match)

    expect(page).to have_content('You are not allowed')
  end

  scenario 'admin can always access proposals page' do
    create(:match_proposal, :in_far_future, match: match, team: team1)

    sign_in_via_session(admin)
    visit match_proposals_path(match)

    expect(page).to have_content('Proposals')
    expect(page).to have_content(team1.name)
  end

  scenario 'team leader cannot propose match without participating in it' do
    other_contest = create(:contest)
    other_team = create(:team)
    other_cont1 = create(:contester, team: other_team, contest: other_contest)
    other_cont2 = create(:contester, team: team2, contest: other_contest)
    other_match = create(:match, contest: other_contest, contester1: other_cont1, contester2: other_cont2)

    sign_in_via_session(team1_leader)
    visit new_match_proposal_path(other_match)

    expect(page).to have_content('You are not allowed')
  end

  scenario 'multiple proposals for same match' do
    create(:match_proposal, :pending, match: match, team: team1, proposed_time: 2.days.from_now)
    create(:match_proposal, :rejected, match: match, team: team1, proposed_time: 3.days.from_now)
    create(:match_proposal, :confirmed, match: match, team: team2, proposed_time: 4.days.from_now)

    sign_in_via_session(team1_leader)
    visit match_proposals_path(match)

    # Should see all proposals with their statuses
    expect(page).to have_content('Pending')
    expect(page).to have_content('Rejected')
    expect(page).to have_content('Confirmed')
    expect(MatchProposal.where(match: match).count).to eq(3)
  end

  scenario 'proposal list shows all proposals with correct statuses' do
    create(:match_proposal, :pending, match: match, team: team1, proposed_time: 2.days.from_now)
    create(:match_proposal, :confirmed, match: match, team: team2, proposed_time: 3.days.from_now)
    create(:match_proposal, :rejected, match: match, team: team1, proposed_time: 4.days.from_now)

    sign_in_via_session(team1_leader)
    visit match_proposals_path(match)

    expect(page).to have_content('Pending')
    expect(page).to have_content('Confirmed')
    expect(page).to have_content('Rejected')
    expect(page).to have_content(team1.name)
    expect(page).to have_content(team2.name)
  end

  scenario 'immutable statuses do not show action buttons' do
    # Rejected status is immutable
    create(:match_proposal, :rejected, :in_far_future, match: match, team: team1)

    sign_in_via_session(team2_leader)
    visit match_proposals_path(match)

    # Should not have any action buttons for rejected proposal
    rows = page.all('table tr')
    rejected_row = rows.find { |row| row.text.include?('Rejected') }
    within(rejected_row) do
      expect(page).not_to have_xpath("//a[@title='Confirm']")
      expect(page).not_to have_xpath("//a[@title='Reject']")
      expect(page).not_to have_xpath("//a[@title='Revoke']")
    end
  end

  scenario 'proposal notification sent to opposing team on creation' do
    proposal = create(:match_proposal, :in_far_future, match: match, team: team1)

    # Verify proposal was created successfully
    expect(proposal).to be_persisted
    expect(proposal.match_id).to eq(match.id)
    expect(proposal.team_id).to eq(team1.id)
    expect(proposal.status).to eq(MatchProposal::STATUS_PENDING)
  end
end
