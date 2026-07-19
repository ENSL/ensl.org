# frozen_string_literal: true

require 'rails_helper'

RSpec.feature 'Poll voting', type: :feature, js: true do
  let!(:category) { FactoryBot.create(:category, :news) }
  let!(:author) { FactoryBot.create(:user) }
  let!(:poll) do
    p = Poll.new(question: 'Which?')
    p.options.build(option: 'A')
    p.options.build(option: 'B')
    p.save!
    p
  end

  scenario 'user votes on a poll' do
    user = FactoryBot.create(:user)
    sign_in_via_session(user)

    # Visit front page where poll widget appears
    visit '/'

    expect(page).to have_content('Which?')

    # Click the vote link (JS submits hidden form). This should create a Vote.
    expect do
      find('a.vote-link', match: :first).click
      # wait for redirect/flash
      expect(page).to have_content('Voted successfully.').or have_content('Vote recorded')
    end.to change { Vote.count }.by(1)
  end

  scenario 'user cannot vote twice and options are disabled after voting' do
    user = FactoryBot.create(:user)

    # login
    visit '/sessions/login'
    fill_in 'login[username]', with: user.username
    fill_in 'login[password]', with: user.raw_password
    click_button 'Login'

    visit '/'

    expect(page).to have_content('Which?')

    # Cast a vote
    find('a.vote-link', match: :first).click
    expect(page).to have_content('Voted successfully.').or have_content('Vote recorded')

    # After voting, options should be disabled/greyed out (have .disabled class or no active vote-link)
    expect(page).to have_no_selector('a.vote-link:not(.disabled)', visible: :all)

    # Confirm a second click does not create another Vote
    count = Vote.count
    if page.has_selector?('a.vote-link:not(.disabled)', visible: :all)
      find('a.vote-link:not(.disabled)', match: :first).click
    end
    expect(Vote.count).to eq(count)
  end
end
