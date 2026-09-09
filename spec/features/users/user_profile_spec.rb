# frozen_string_literal: true

require 'rails_helper'

feature 'User profile', js: true do
  def displayed_time(time, timezone = Rails.application.config.time_zone)
    Time.use_zone(timezone) { time.strftime('%d %B %y %H:%M') }
  end

  scenario "shows a freshly created user's current last-visit time, not a stale frozen default" do
    # Regression guard: `User#lastvisit` used to default to `Time.now.utc` evaluated
    # once at class load, so a brand new user's profile could show a "Last visit"
    # stamp from whenever the app booted instead of when they actually showed up.
    registrant = create(:user)

    visit user_path(registrant)

    expect(page).to have_content(displayed_time(registrant.lastvisit))
    expect(registrant.lastvisit).to be_within(5).of(Time.now.utc)
  end

  scenario 'reflects the moment a player logged back in after a period of inactivity' do
    registrant = create(:user, raw_password: 'password123')
    registrant.update!(lastvisit: 3.days.ago.change(usec: 0))
    old_last_visit_text = displayed_time(registrant.reload.lastvisit)

    visit user_path(registrant)
    expect(page).to have_content(old_last_visit_text)

    sign_in_as(registrant)
    registrant.reload

    expect(registrant.lastvisit).to be_within(5).of(Time.now.utc)

    visit user_path(registrant)
    expect(page).to have_content(displayed_time(registrant.lastvisit, registrant.time_zone))
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
    old_last_visit_text = displayed_time(registrant.lastvisit, registrant.time_zone)

    visit gather_path(gather)

    expect(registrant.reload.lastvisit).to be_within(5).of(Time.now.utc)

    visit user_path(registrant)
    expect(page).to have_content(displayed_time(registrant.lastvisit, registrant.time_zone))
    expect(page).not_to have_content(old_last_visit_text)
  end

  scenario 'updates all editable profile fields through the profile form' do
    user = create(:user, raw_password: 'PasswordABC123')
    avatar = Tempfile.new(['avatar', '.png'])
    image = Magick::Image.new(2, 2) { |canvas| canvas.background_color = 'red' }
    image.write(avatar.path)
    avatar.rewind
    profile_id = user.profile.id

    sign_in_as(user)
    visit edit_user_path(user)

    fill_in 'user_raw_password', with: 'UpdatedPasswordABC123'
    fill_in 'user_email', with: 'updated@example.com'
    find("label.checkbox[for='user_public_email']").click
    fill_in 'user_steamid', with: '0:1:123456789'
    fill_in 'user_firstname', with: 'Updated'
    fill_in 'user_lastname', with: 'Member'
    select '1990', from: 'user_birthdate_1i'
    select 'January', from: 'user_birthdate_2i'
    select '2', from: 'user_birthdate_3i'

    click_link 'Profile'
    fill_in 'user_profile_attributes_steam_profile', with: 'updated_player'
    fill_in 'user_profile_attributes_web', with: 'https://example.com'
    fill_in 'user_profile_attributes_achievements', with: 'Won the cup'
    fill_in 'user_profile_attributes_signature', with: 'Updated signature'
    attach_file 'user_profile_attributes_avatar', avatar.path
    fill_in 'user_profile_attributes_stream', with: 'https://twitch.tv/updated_player'

    click_link I18n.t('profile.locals')
    find("#user_country option[value='NO']").select_option
    fill_in 'user_profile_attributes_town', with: 'Oslo'
    find("#user_time_zone option[value='London']").select_option

    click_link 'Notifications'
    %w[news articles movies gather push_gather own_match any_match].each do |notification|
      find("label.checkbox[for='user_profile_attributes_notify_#{notification}']").click
    end
    find("label.checkbox[for='user_profile_attributes_notify_challenge']").click
    find("label.checkbox[for='user_profile_attributes_notify_pms']").click

    click_button 'Update Profile'

    expect(page).to have_content(I18n.t('flash.actions.update.notice', resource_name: User.model_name.human))
    expect(user.reload.attributes.slice('firstname', 'lastname', 'email', 'steamid', 'birthdate', 'country', 'time_zone',
                                        'public_email')).to eq(
                                          'firstname' => 'Updated',
                                          'lastname' => 'Member',
                                          'email' => 'updated@example.com',
                                          'steamid' => '0:1:123456789',
                                          'birthdate' => Date.new(1990, 1, 2),
                                          'country' => 'NO',
                                          'time_zone' => 'London',
                                          'public_email' => true
                                        )
    expect(user.profile).to have_attributes(
      id: profile_id,
      steam_profile: 'updated_player',
      web: 'https://example.com',
      achievements: 'Won the cup',
      signature: 'Updated signature',
      stream: 'https://twitch.tv/updated_player',
      town: 'Oslo',
      notify_news: true,
      notify_articles: true,
      notify_movies: true,
      notify_gather: true,
      notify_push_gather: true,
      notify_own_match: true,
      notify_any_match: true,
      notify_challenge: false,
      notify_pms: false
    )
    expect(user.profile[:avatar]).to eq("#{profile_id}.png")
    expect(User.authenticate(username: user.username, password: 'UpdatedPasswordABC123')).to eq(user)
  ensure
    image&.destroy!
    avatar&.close!
  end
end
