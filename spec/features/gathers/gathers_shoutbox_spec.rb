require 'rails_helper'

feature 'Gathers', js: true do
  let!(:user) { create :user }
  let!(:gather) { create :gather, :running }

  feature 'Shoutbox' do
    background do
      sign_in_as user
    end

    scenario 'create shout' do
      # Run ActiveJob inline so Turbo Stream broadcasts are delivered in-process
      ActiveJob::Base.queue_adapter = :inline
      visit gather_path(gather)
      expect(page).to have_selector('turbo-cable-stream-source[connected]', visible: :all, wait: 10)
      shout = rand(100_000).to_s
      within("#new_shout_Gather_#{gather.id}") do
        fill_in "shout_Gather_#{gather.id}_text", with: shout
        click_button 'Shout!'
      end
      expect(page).to have_content(shout, wait: 5)
      expect(Shoutmsg.where(text: shout).count).to eq(1)
      expect(page).to have_field("shout_Gather_#{gather.id}_text", with: '')
    end

    scenario 'enter more than 100 characters' do
      valid_shout = 100.times.map { 'a' }.join
      invalid_shout = 101.times.map { 'a' }.join
      # Run ActiveJob inline so Turbo Stream broadcasts are delivered in-process
      ActiveJob::Base.queue_adapter = :inline
      visit gather_path(gather)
      expect(page).to have_selector('turbo-cable-stream-source[connected]', visible: :all, wait: 10)
      expect(page).to_not have_content('Maximum shout length exceeded')
      before_count = Shoutmsg.count
      within("#new_shout_Gather_#{gather.id}") do
        fill_in "shout_Gather_#{gather.id}_text", with: invalid_shout
        click_button 'Shout!'
      end
      # invalid shouts should not create records and the input should remain populated
      expect(page).to have_field("shout_Gather_#{gather.id}_text", with: invalid_shout)
      expect(Shoutmsg.count).to eq(before_count)
      expect(page).to have_no_content(invalid_shout, wait: 2)
      within("#new_shout_Gather_#{gather.id}") do
        fill_in "shout_Gather_#{gather.id}_text", with: valid_shout
        click_button 'Shout!'
      end
      expect(page).to have_content(valid_shout, wait: 5)
      expect(Shoutmsg.where(text: valid_shout).count).to eq(1)
    end

    scenario 'creating shout while banned' do
      Ban.create! ban_type: Ban::TYPE_MUTE, expiry: Time.now + 10.days, user_name: user.username
      visit root_path
      expect(find('#sidebar')).to have_content 'You have been muted.'
    end
  end
end
