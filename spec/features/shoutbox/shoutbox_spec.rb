# frozen_string_literal: true

require 'rails_helper'

feature 'Shoutbox (Turbo Streams)', js: true do
  let!(:user) { create :user }
  let!(:other_user) { create :user }

  def shout_texts_in(selector)
    all("#{selector} .shoutmsg .contents", minimum: 0).map(&:text)
  end

  background do
    sign_in_via_session(user)
    visit root_path
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
      sign_in_via_session(user)
      visit root_path
      expect(page).to have_selector('turbo-cable-stream-source[connected]', visible: :all, wait: 10)
    end

    Capybara.using_session(:receiver) do
      sign_in_via_session(other_user)
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
    within("#new_shout_Gather_#{gather.id}") do
      fill_in "shout_Gather_#{gather.id}_text", with: first_shout
      click_button 'Shout!'
    end

    within("#shout_Gather_#{gather.id}") do
      expect(page).to have_content(first_shout, wait: 5)
    end
    expect(page).to have_field("shout_Gather_#{gather.id}_text", with: '', wait: 5)

    second_shout = SecureRandom.hex(6)
    within("#new_shout_Gather_#{gather.id}") do
      fill_in "shout_Gather_#{gather.id}_text", with: second_shout
      click_button 'Shout!'
    end

    within("#shout_Gather_#{gather.id}") do
      expect(page).to have_content(second_shout, wait: 5)
      expect(page).to have_content(first_shout)
      expect(page).to have_text(/#{Regexp.escape(first_shout)}.*#{Regexp.escape(second_shout)}/m)
    end
  end

  scenario 'main shoutbox is scrollable, limited to newest 8, and prepends newest shouts at top' do
    prefix = "main-buffer-#{SecureRandom.hex(4)}"
    12.times { |n| create(:shoutmsg, text: "#{prefix}-#{n}") }

    visit root_path
    expect(page).to have_selector('#shoutbox .shoutmsg', minimum: 1)

    overflow_y = page.evaluate_script("window.getComputedStyle(document.querySelector('#shoutbox')).overflowY")
    max_height = page.evaluate_script("window.getComputedStyle(document.querySelector('#shoutbox')).maxHeight")
    expect(overflow_y).to eq('auto')
    expect(max_height).to eq('240px')

    texts = shout_texts_in('#shoutbox').join(' ')
    expect(texts).to include("#{prefix}-11")
    expect(texts).to include("#{prefix}-4")
    expect(texts).not_to include("#{prefix}-3")
    expect(texts).not_to include("#{prefix}-0")

    first_text = all('#shoutbox .shoutmsg .contents', minimum: 1).first.text
    expect(first_text).to include("#{prefix}-11")
  end

  scenario 'main shoutbox mousewheel changes scroll position' do
    20.times { |n| create(:shoutmsg, text: "wheel-main-#{n}-#{SecureRandom.hex(2)}") }

    visit root_path
    expect(page).to have_selector('#shoutbox .shoutmsg', minimum: 1)

    page.execute_script("document.querySelector('#shoutbox').scrollTop = 100;")
    before = page.evaluate_script("document.querySelector('#shoutbox').scrollTop")

    page.execute_script("$(document.querySelector('#shoutbox')).trigger('mousewheel', [120]);")
    sleep 0.1
    after = page.evaluate_script("document.querySelector('#shoutbox').scrollTop")

    expect(after).not_to eq(before)
  end
end
