require 'spec_helper'

feature 'Shoutbox', js: true do
	let!(:user) { create :user }

	background do
		sign_in_as user
	end

	scenario 'creating a valid shout' do
		visit root_path
		shout = rand(100000).to_s
		fill_in 'shoutbox_text', with: shout
		click_button 'Shout!'
		expect(page).to have_content(shout)
	end

	scenario 'enter more than 100 characters' do
		valid_shout = 100.times.map { "a" }.join
		invalid_shout = 101.times.map { "a" }.join
		visit root_path
		expect(page).to_not have_content("Maximum shout length exceeded")
		fill_in 'shoutbox_text', with: invalid_shout
		expect(page).to have_content("Maximum shout length exceeded")
		fill_in 'shoutbox_text', with: valid_shout
		expect(page).to_not have_content("Maximum shout length exceeded")
	end

	scenario 'creating shout while banned' do
		Ban.create! ban_type: Ban::TYPE_MUTE, expiry: Time.now + 10.days, user_name: user.username
		visit root_path
		expect(find("#sidebar")).to have_content "You have been muted."
	end
end