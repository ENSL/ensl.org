# frozen_string_literal: true

require 'rails_helper'

feature 'Message creation', :js do
  let!(:sender) { create :user }
  let!(:recipient) { create :user }

  background do
    sign_in_as sender
  end

  scenario 'User creates a message' do
    visit root_path

    within '.links' do
      click_link 'Messages'
    end

    expect(page).to have_text('Sent (0)')
    visit user_path(recipient)
    expect(page).to have_text(recipient.username)

    click_link 'Send PM'
    expect(page).to have_text('New Message')

    title = 'This is my title'
    message = 'This is my message'
    fill_in 'Title', with: title
    fill_in 'Text', with: message
    click_button 'Send Message'

    expect(page).to have_text('Message was successfully sent.')
    expect(page).to have_text(title)
    expect(page).to have_text(message)

    within '.links' do
      click_link 'Messages'
    end

    expect(page).to have_text('Sent (1)')

    within '#sent' do
      expect(page).to have_text(title)
      expect(page).to have_text(message)
      expect(page).to have_text(sender.username)
      expect(page).to have_text(recipient.username)
    end
  end
end

feature 'Message receiving' do
  let!(:message) { create :message }

  background do
    sign_in_as message.recipient
  end

  scenario 'User receives a message' do
    visit root_path

    within '.links' do
      expect(page).to have_text('(1)')
      click_link 'Messages'
    end

    expect(page).to have_text(message.title)
    expect(page).to have_text(message.text)
    expect(page).to have_text(message.sender.username)
  end
end
