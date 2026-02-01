require 'rails_helper'

RSpec.feature 'CustomUrls administrate', type: :feature do
  let!(:category) { FactoryBot.create(:category, :news) }
  let!(:author) { FactoryBot.create(:user) }
  let!(:article) { FactoryBot.create(:article, title: 'Test Article', user: author, category: category) }

  scenario 'admin creates a custom url and the slug routes to the article' do
    admin = FactoryBot.create(:user, :admin)

    # Login as admin via the login form
    visit '/users/login'
    fill_in 'login[username]', with: admin.username
    fill_in 'login[password]', with: admin.raw_password
    click_button 'Login'

    visit '/custom_urls'
    expect(page).to have_content('Custom URLs - Admin Panel')

    fill_in 'custom_url_name', with: 'test-slug'
    select article.title, from: 'custom_url_article_id'
    click_button 'Add'

    within('#custom-urls') do
      expect(page).to have_content('test-slug')
      expect(page).to have_content('Test Article')
    end

    visit '/test-slug'
    expect(page).to have_content('Test Article')
  end
end
