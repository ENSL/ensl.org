# frozen_string_literal: true

require 'rails_helper'

RSpec.feature 'CustomUrls administrate', type: :feature, js: true do
  let!(:category) { FactoryBot.create(:category, :news) }
  let!(:author) { FactoryBot.create(:user) }
  let!(:article) { FactoryBot.create(:article, title: 'Test Article', user: author, category: category) }
  let!(:replacement_article) do
    FactoryBot.create(:article, title: 'Replacement Article', user: author, category: category)
  end

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

    created = CustomUrl.find_by!(name: 'test-slug')
    expect(page).to have_field("custom_url_#{created.id}_form_name", with: 'test-slug')
    expect(page).to have_select("custom_url_#{created.id}_form_article_id", selected: 'Test Article')

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

  scenario 'admin updates a custom url inline in name and article columns' do
    admin = FactoryBot.create(:user, :admin)
    custom_url = CustomUrl.create!(name: 'old-slug', article: article)

    sign_in_via_session(admin)

    visit '/custom_urls'

    fill_in "custom_url_#{custom_url.id}_form_name", with: 'new-slug'
    select replacement_article.title, from: "custom_url_#{custom_url.id}_form_article_id"
    find("tr#custom_url_#{custom_url.id} a[title='Save custom URL']").click

    expect(page).to have_css('#notification .message.notice', text: I18n.t('custom_urls.update.success'))
    expect(page).to have_field("custom_url_#{custom_url.id}_form_name", with: 'new-slug')
    expect(page).to have_select("custom_url_#{custom_url.id}_form_article_id", selected: replacement_article.title)

    visit '/new-slug'
    expect(page).to have_content(replacement_article.title)
  end

  scenario 'admin sees an error when updating a custom url with an invalid name' do
    admin = FactoryBot.create(:user, :admin)
    custom_url = CustomUrl.create!(name: 'old-slug', article: article)

    sign_in_via_session(admin)

    visit '/custom_urls'

    fill_in "custom_url_#{custom_url.id}_form_name", with: ''
    find("tr#custom_url_#{custom_url.id} a[title='Save custom URL']").click

    expect(page).to have_css('#notification .message.error')
    expect(custom_url.reload.name).to eq('old-slug')
  end

  scenario 'admin cannot delete menu-linked custom urls' do
    admin = FactoryBot.create(:user, :admin)
    protected_url = CustomUrl.create!(name: 'rules', article: article)

    sign_in_via_session(admin)

    visit '/custom_urls'

    expect(page).to have_selector("tr#custom_url_#{protected_url.id}")
    expect(page).to have_no_selector("tr#custom_url_#{protected_url.id} a[title='Delete custom URL']")
  end
end
