# frozen_string_literal: true

require 'rails_helper'

feature 'Shoutbox emoji shortcodes', js: true do
  let!(:user) { create :user }

  background do
    sign_in_via_session(user)
    visit root_path
    ActiveJob::Base.queue_adapter = :inline
  end

  scenario 'shortcodes are converted and shout input continues working after submit' do
    visit root_path
    expect(page).to have_selector('turbo-cable-stream-source[connected]', visible: :all, wait: 10)

    fill_in 'shoutbox_text', with: ':smile:'
    click_button 'Shout!'
    expect(page).to have_field('shoutbox_text', with: '', wait: 5)

    expect(Shoutmsg.order(:id).last&.text).to eq('😄')

    fill_in 'shoutbox_text', with: ':heart:'
    click_button 'Shout!'
    expect(page).to have_field('shoutbox_text', with: '', wait: 5)

    latest_two_texts = Shoutmsg.order(id: :desc).limit(2).pluck(:text)
    expect(latest_two_texts).to include('😄', '❤️')
  end

  scenario 'autocomplete menu appears and inserts selected shortcode token' do
    visit root_path
    expect(page).to have_selector('turbo-cable-stream-source[connected]', visible: :all, wait: 10)

    input = find_field('shoutbox_text')
    input.send_keys(':smi')

    expect(page).to have_css('.tribute-container li', text: ':smile:', wait: 5)
    find('.tribute-container li', text: ':smile:').click

    expect(find_field('shoutbox_text').value).to include(':smile:')
  end
end
