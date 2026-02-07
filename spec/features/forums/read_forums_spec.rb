require 'rails_helper'

feature 'User reads forums', js: true do
  before do
    create_list(:forum, 5, :with_content)
  end

  context 'as a basic user' do
    let!(:user) { create(:user) }

    before do
      sign_in_as(user)
    end

    it 'has forum data' do
      expect(Forum.count).to be >= 5
    end

    it 'has forum header' do
      visit forums_path
      expect(page).to have_css('td.forum h5', wait: 5)
    end

    it 'has forum description' do
      visit forums_path
      el = first('td.forum', wait: 3)
      expect(el).to have_text(/Forum Description/i)
    end

    it 'can click last post' do
      visit forums_path
      first('td.last > a', wait: 5).click
      # puts "DBG counts: Forum=#{Forum.count} Topic=#{Topic.count} Post=#{Post.count}"
      # save_page('tmp/debug_page.html')
      expect(page).to have_current_path(%r{topics/\d+}, wait: 5)
    end
  end

  private

  def long_text(len = 10_000)
    (0..len).map { (0...8).map { rand(65..90).chr }.join }.join(' ') # 90008
  end
end
