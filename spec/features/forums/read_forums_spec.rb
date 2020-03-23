require 'rails_helper'

feature 'User reads forums', js: :true do
  before :all do
    create_list(:forum, 5, :with_content)
  end

  context 'as a basic user' do
    let!(:user) { create(:user) }

    before do
      sign_in_as(user)
    end

    it 'has forum header' do
      visit forums_path
      expect(page).to have_selector("td.forum h5")
    end

    it 'has forum description' do
      skip
      visit forums_path
      expect("td.forum").to have_content()
    end

    # FIXME
    it 'can click last post' do
      skip
      find('td.last>a').click
      expect(response).to have_http_status(200)
    end
  end

  private

  def long_text(len = 10_000)
    (0..len).map{ (0...8).map { (65 + rand(26)).chr }.join }.join(" ") # 90008
  end
end
