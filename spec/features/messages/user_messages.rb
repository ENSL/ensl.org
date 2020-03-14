require 'rails_helper'

feature 'Message creation' do
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
    expect(page).to have_content('Sent (0)')
    visit user_path(recipient)
    expect(page).to have_content(recipient.username)
    click_link 'Send PM'
    expect(page).to have_content('New Message')
    title = "This is my title"
    message = "This is my message"
    fill_in 'Title', with: title
    fill_in 'Text', with: message
    click_button 'Send Message'
    expect(page).to have_content('Message was successfully sent.')
    expect(page).to have_content(title)
    expect(page).to have_content(message)
    within '.links' do
	    click_link 'Messages'
    end
    expect(page).to have_content('Sent (1)')
    within '#sent' do
	    expect(page).to have_content(title)
	    expect(page).to have_content(message)
	    expect(page).to have_content(sender.username)
	    expect(page).to have_content(recipient.username)
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
    	expect(page).to have_content('(1)')
	    click_link 'Messages'
    end
    expect(page).to have_content(message.title)
    expect(page).to have_content(message.text)
    expect(page).to have_content(message.sender.username)
  end
end