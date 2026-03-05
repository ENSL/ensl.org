require 'rails_helper'

feature 'Gathers', js: true do
  let!(:user) { create :user }
  let!(:gather) { create :gather, :running }

  def gather_selector
    "#shout_Gather_#{gather.id}"
  end

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

    scenario 'emoji autocomplete popup appears in gather shout input' do
      visit gather_path(gather)
      expect(page).to have_selector('turbo-cable-stream-source[connected]', visible: :all, wait: 10)

      input = find_field("shout_Gather_#{gather.id}_text")
      input.send_keys(':smi')

      expect(page).to have_css('.tribute-container li', text: ':smile:', wait: 5)
      find('.tribute-container li', text: ':smile:').click

      expect(find_field("shout_Gather_#{gather.id}_text").value).to include(':smile:')
    end

    scenario 'creating shout while banned' do
      Ban.create! ban_type: Ban::TYPE_MUTE, expiry: Time.now + 10.days, user_name: user.username
      visit root_path
      expect(find('#sidebar')).to have_content 'You have been muted.'
    end

    scenario 'gather shoutbox is scrollable, keeps full buffer, appends at bottom, and autoscrolls to latest' do
      prefix = "gather-buffer-#{SecureRandom.hex(4)}"
      12.times { |n| create(:shoutmsg, shoutable: gather, user: user, text: "#{prefix}-#{n}") }

      visit gather_path(gather)
      expect(page).to have_selector("#{gather_selector} .shoutmsg", minimum: 1)

      overflow_y = page.evaluate_script("window.getComputedStyle(document.querySelector('#{gather_selector}')).overflowY")
      max_height = page.evaluate_script("window.getComputedStyle(document.querySelector('#{gather_selector}')).maxHeight")
      expect(overflow_y).to eq('auto')
      expect(max_height).to eq('240px')

      texts = all("#{gather_selector} .shoutmsg .contents", minimum: 12).map(&:text).join(' ')
      expect(texts).to include("#{prefix}-0")
      expect(texts).to include("#{prefix}-11")

      first_text = all("#{gather_selector} .shoutmsg .contents", minimum: 12).first.text
      last_text = all("#{gather_selector} .shoutmsg .contents", minimum: 12).last.text
      expect(first_text).to include("#{prefix}-0")
      expect(last_text).to include("#{prefix}-11")

      scroll_top = page.evaluate_script("document.querySelector('#{gather_selector}').scrollTop")
      max_scroll = page.evaluate_script("(function(){ const el = document.querySelector('#{gather_selector}'); return el.scrollHeight - el.clientHeight; })()")
      expect(scroll_top).to be >= [max_scroll - 10, 0].max
    end
  end
end
