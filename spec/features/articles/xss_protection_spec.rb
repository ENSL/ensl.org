# frozen_string_literal: true

require 'rails_helper'

feature 'XSS Protection in Articles', js: true do
  let!(:category) { create(:category, domain: Category::DOMAIN_NEWS) }
  let!(:admin) { create(:user, :admin) }

  scenario 'BBCode format prevents XSS attacks' do
    sign_in_as(admin)
    visit new_article_path

    expect(page).to have_selector('#article_title', wait: 5)
    fill_in 'article_title', with: 'XSS Test Article'

    select 'BBCode', from: 'article_text_coding'

    # Try to inject script tag via BBCode
    expect(page).to have_selector('#article_text', visible: :all, wait: 5)
    fill_tinymce 'article_text', '[b]Safe content[/b]<script>alert("XSS")</script>'

    click_button I18n.t('helpers.submit.post.create')

    expect(page).to have_content(I18n.t('articles_create'))
    expect(page).to have_content('Safe content')

    # Verify script tag is not present in the rendered HTML
    expect(page).not_to have_selector('script', text: 'alert', visible: :all)
    expect(page.html).not_to include('<script>alert')
  end

  scenario 'Markdown format prevents XSS attacks' do
    sign_in_as(admin)
    visit new_article_path

    expect(page).to have_selector('#article_title', wait: 5)
    fill_in 'article_title', with: 'Markdown XSS Test'

    select 'Markdown', from: 'article_text_coding'

    # Try to inject script tag via Markdown
    expect(page).to have_selector('#article_text', visible: :all, wait: 5)
    page.execute_script("if (window.tinymce && tinymce.get('article_text')) { tinymce.get('article_text').remove(); }")
    page.execute_script("document.getElementById('article_text').value = '**Safe content** <script>alert(\\\"XSS\\\")</script>'")

    click_button I18n.t('helpers.submit.post.create')

    expect(page).to have_content(I18n.t('articles_create'))
    expect(page).to have_content('Safe content')

    # Verify script tag is not present in the rendered HTML
    expect(page).not_to have_selector('script', text: 'alert', visible: :all)
    expect(page.html).not_to include('<script>alert')
  end

  scenario 'Markdown format prevents iframe injection' do
    sign_in_as(admin)
    visit new_article_path

    expect(page).to have_selector('#article_title', wait: 5)
    fill_in 'article_title', with: 'Iframe Test'

    select 'Markdown', from: 'article_text_coding'

    expect(page).to have_selector('#article_text', visible: :all, wait: 5)
    fill_tinymce 'article_text', '**Text** <iframe src="http://evil.com"></iframe>'

    click_button I18n.t('helpers.submit.post.create')

    expect(page).to have_content(I18n.t('articles_create'))

    # Verify iframe is not present
    expect(page).not_to have_selector('iframe', visible: :all)
    expect(page.html).not_to include('<iframe')
  end

  scenario 'BBCode format prevents event handler injection' do
    sign_in_as(admin)
    visit new_article_path

    expect(page).to have_selector('#article_title', wait: 5)
    fill_in 'article_title', with: 'Event Handler Test'

    select 'BBCode', from: 'article_text_coding'

    expect(page).to have_selector('#article_text', visible: :all, wait: 5)
    fill_tinymce 'article_text', '[b]Text[/b]<img src=x onerror="alert(1)">'

    click_button I18n.t('helpers.submit.post.create')

    expect(page).to have_content(I18n.t('articles_create'))

    # Verify event handler is not present
    expect(page.html).not_to include('onerror=')
  end
end
