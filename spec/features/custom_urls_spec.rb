require 'rails_helper'

RSpec.feature 'CustomUrls administrate', type: :feature, js: true do
  let!(:category) { FactoryBot.create(:category, :news) }
  let!(:author) { FactoryBot.create(:user) }
  let!(:article) { FactoryBot.create(:article, title: 'Test Article', user: author, category: category) }

  scenario 'admin creates a custom url and the slug routes to the article' do
    admin = FactoryBot.create(:user, :admin)

    sign_in_via_session(admin)

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
