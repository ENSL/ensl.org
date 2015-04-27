require 'spec_helper'

feature 'Shoutbox' do
	background do
		@user = create :user
		sign_in_as @user
		visit root_path
	end

	feature 'user creates a shout', js: true do
		scenario 'shouting with valid content' do
			shout = rand(100000).to_s
			fill_in 'shoutbox_text', with: shout
			click_button 'Shout!'
			expect(page).to have_content(shout)
		end

		scenario 'unable to while banned' do
			@user.bans.create! ban_type: Ban::TYPE_MUTE, expiry: Time.now + 10.days
			shout = rand(100000).to_s
			fill_in 'shoutbox_text', with: shout
			click_button 'Shout!'
			expect(page).to_not have_content(shout)
		end
	end	
end