# frozen_string_literal: true

require 'rails_helper'

feature 'User profile', js: true do
  scenario "shows a freshly created user's current last-visit time, not a stale frozen default" do
    # Regression guard: `User#lastvisit` used to default to `Time.now.utc` evaluated
    # once at class load, so a brand new user's profile could show a "Last visit"
    # stamp from whenever the app booted instead of when they actually showed up.
    registrant = create(:user)

    visit user_path(registrant)

    expect(page).to have_content(registrant.lastvisit.strftime('%d %B %y %H:%M'))
    expect(registrant.lastvisit).to be_within(5).of(Time.now.utc)
  end

  scenario 'reflects the moment a player logged back in after a period of inactivity' do
    registrant = create(:user, raw_password: 'password123')
    registrant.update!(lastvisit: 3.days.ago.change(usec: 0))
    old_last_visit_text = registrant.lastvisit.strftime('%d %B %y %H:%M')

    visit user_path(registrant)
    expect(page).to have_content(old_last_visit_text)

    sign_in_as(registrant)
    registrant.reload

    expect(registrant.lastvisit).to be_within(5).of(Time.now.utc)

    visit user_path(registrant)
    expect(page).to have_content(registrant.lastvisit.strftime('%d %B %y %H:%M'))
    expect(page).not_to have_content(old_last_visit_text)
  end

  scenario 'updates from visiting an unrelated page while idle, not just from logging in' do
    # Authentication#update_user (the before_action that calls
    # touch_last_visit_if_stale!) runs on every authenticated request, not just
    # login. Prove that browsing some other page - a gather here - while an
    # existing session goes idle is what refreshes lastvisit, and that the
    # profile page picks up that same value afterwards.
    registrant = create(:user, raw_password: 'password123')
    gather = FactoryBot.create(:gather, maps_count: 3, servers_count: 2)

    sign_in_via_session(registrant)

    # Session/cookie stays valid; only their lastvisit falls behind as if they
    # left the tab open without interacting.
    registrant.update!(lastvisit: 3.days.ago.change(usec: 0))
    old_last_visit_text = registrant.lastvisit.strftime('%d %B %y %H:%M')

    visit gather_path(gather)

    expect(registrant.reload.lastvisit).to be_within(5).of(Time.now.utc)

    visit user_path(registrant)
    expect(page).to have_content(registrant.lastvisit.strftime('%d %B %y %H:%M'))
    expect(page).not_to have_content(old_last_visit_text)
  end
end
