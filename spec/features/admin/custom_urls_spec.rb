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

    expect(page).to have_css('#notification .message.notice',
                             text: I18n.t('flash.actions.create.notice', resource_name: CustomUrl.model_name.human))

    within('#custom-urls') do
      expect(page).to have_content('test-slug')
      expect(page).to have_content('Test Article')
    end

    visit '/test-slug'
    expect(page).to have_content('Test Article')
  end

  scenario 'admin sees validation errors and article dropdown stays visible' do
    admin = FactoryBot.create(:user, :admin)

    sign_in_via_session(admin)

    visit '/custom_urls'

    fill_in 'custom_url_name', with: ''
    select article.title, from: 'custom_url_article_id'
    click_button 'Add'

    expect(page).to have_css('.errors-block')
    expect(page).to have_selector('#custom_url_article_id', visible: :visible)
  end
end
