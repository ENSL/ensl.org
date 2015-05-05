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

	scenario 'creating shout while banned' do
		Ban.create! ban_type: Ban::TYPE_MUTE, expiry: Time.now + 10.days, user_name: user.username
		visit root_path
		expect(find("#sidebar")).to have_content "You have been muted."
	end
end