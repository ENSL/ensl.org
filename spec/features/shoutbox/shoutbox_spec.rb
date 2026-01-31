require 'rails_helper'

feature 'Shoutbox (Turbo Streams)', js: true do
  let!(:user) { create :user }
  let!(:other_user) { create :user }

  background do
    sign_in_as user
    # Run ActiveJob inline so Turbo Stream broadcasts are delivered in-process
    ActiveJob::Base.queue_adapter = :inline
  end

  scenario 'creating a valid shout broadcasts and resets the form' do
    visit root_path
    expect(page).to have_selector('turbo-cable-stream-source[connected]', visible: :all, wait: 10)
    first_shout = SecureRandom.hex(6)
    fill_in 'shoutbox_text', with: first_shout
    # submit using a real user action so Turbo/JS handlers run as in the browser
    click_button 'Shout!'
    within('#shoutbox') do
      expect(page).to have_content(first_shout, wait: 5)
    end
    expect(Shoutmsg.where(text: first_shout).count).to eq(1)
    expect(page).to have_field('shoutbox_text', with: '')

    second_shout = SecureRandom.hex(6)
    fill_in 'shoutbox_text', with: second_shout
    click_button 'Shout!'

    within('#shoutbox') do
      expect(page).to have_content(second_shout, wait: 5)
      expect(page).to have_content(first_shout)
      expect(page).to have_text(/#{Regexp.escape(second_shout)}.*#{Regexp.escape(first_shout)}/m)
    end
    expect(Shoutmsg.where(text: second_shout).count).to eq(1)
  end

  scenario 'shows validation error for too-long shouts' do
    valid_shout = 'a' * 100
    invalid_shout = 'a' * 101

    visit root_path
    expect(page).to have_selector('turbo-cable-stream-source[connected]', visible: :all, wait: 10)
    expect(page).to_not have_content('Maximum shout length exceeded')

    before_count = Shoutmsg.count
    fill_in 'shoutbox_text', with: invalid_shout
    click_button 'Shout!'

    # invalid shouts should not create records and the input should remain populated
    expect(page).to have_field('shoutbox_text', with: invalid_shout)
    expect(Shoutmsg.count).to eq(before_count)
    expect(page).to have_no_content(invalid_shout, wait: 2)

    fill_in 'shoutbox_text', with: valid_shout
    click_button 'Shout!'

    within('#shoutbox') do
      expect(page).to have_content(valid_shout, wait: 5)
    end
    expect(Shoutmsg.where(text: valid_shout).count).to eq(1)
  end

  scenario 'creating shout while banned' do
    Ban.create!(ban_type: Ban::TYPE_MUTE, expiry: Time.now.utc + 10.days, user_name: user.username)
    visit root_path
    expect(page).to have_selector('#sidebar', text: 'You have been muted.')
  end

  scenario 'another user sees shout without reload' do
    Capybara.using_session(:sender) do
      sign_in_as user
      visit root_path
      expect(page).to have_selector('turbo-cable-stream-source[connected]', visible: :all, wait: 10)
    end

    Capybara.using_session(:receiver) do
      sign_in_as other_user
      visit root_path
      expect(page).to have_selector('turbo-cable-stream-source[connected]', visible: :all, wait: 10)
      expect(page).to have_selector('#shoutbox')
    end

    shout = SecureRandom.hex(6)

    Capybara.using_session(:sender) do
      fill_in 'shoutbox_text', with: shout
      click_button 'Shout!'
      within('#shoutbox') do
        expect(page).to have_content(shout, wait: 5)
      end
    end

    Capybara.using_session(:receiver) do
      within('#shoutbox') do
        expect(page).to have_content(shout, wait: 5)
      end
    end
  end

  scenario 'gather shoutbox maintains chronological order' do
    gather = create(:gather, :running)
    visit gather_path(gather)
    expect(page).to have_selector('turbo-cable-stream-source[connected]', visible: :all, wait: 10)

    first_shout = SecureRandom.hex(6)
    fill_in "shout_Gather_#{gather.id}_text", with: first_shout
    click_button 'Shout!'

    within("#shout_Gather_#{gather.id}") do
      expect(page).to have_content(first_shout, wait: 5)
    end

    second_shout = SecureRandom.hex(6)
    fill_in "shout_Gather_#{gather.id}_text", with: second_shout
    click_button 'Shout!'

    within("#shout_Gather_#{gather.id}") do
      expect(page).to have_content(second_shout, wait: 5)
      expect(page).to have_content(first_shout)
      expect(page).to have_text(/#{Regexp.escape(first_shout)}.*#{Regexp.escape(second_shout)}/m)
    end
  end
end
