require 'rails_helper'

feature 'XSS Protection in Forum Posts and Comments', js: true do
  let!(:user) { create(:user) }

  scenario 'Forum posts prevent script tag injection' do
    topic = create(:topic)

    sign_in_as(user)
    visit topic_path(topic)

    expect(page).to have_selector('#post_text', wait: 5)

    # Try to inject malicious content
    fill_in 'post_text', with: '[b]Safe post[/b]<script>alert("XSS")</script>'
    click_button I18n.t(:reply)

    expect(page).to have_content('Safe post')

    # Verify script tag was stripped
    expect(page).not_to have_selector('script', text: 'alert', visible: :all)
    expect(page.html).not_to include('<script>alert')
  end

  scenario 'Forum posts prevent iframe injection' do
    topic = create(:topic)

    sign_in_as(user)
    visit topic_path(topic)

    expect(page).to have_selector('#post_text', wait: 5)

    fill_in 'post_text', with: '[b]Post[/b]<iframe src="http://evil.com"></iframe>'
    click_button I18n.t(:reply)

    # Verify iframe was stripped
    expect(page).not_to have_selector('iframe', visible: :all)
    expect(page.html).not_to include('<iframe')
  end

  scenario 'Forum posts prevent event handler injection' do
    topic = create(:topic)

    sign_in_as(user)
    visit topic_path(topic)

    expect(page).to have_selector('#post_text', wait: 5)

    fill_in 'post_text', with: '[i]Text[/i]<img src=x onerror="alert(1)">'
    click_button I18n.t(:reply)

    # Verify event handler was stripped
    expect(page.html).not_to include('onerror=')
    expect(page.html).not_to include('<img')
  end

  scenario 'Comments prevent script tag injection' do
    article = create(:article, category: create(:category))

    sign_in_as(user)
    visit article_path(article)

    expect(page).to have_selector('#comment_text', wait: 5)

    # Try to inject malicious content in comment
    fill_in 'comment_text', with: '[b]Safe comment[/b]<script>alert("XSS")</script>'
    click_button I18n.t(:add_comment)

    expect(page).to have_content('Safe comment')

    # Verify script tag was stripped
    expect(page).not_to have_selector('script', text: 'alert', visible: :all)
    expect(page.html).not_to include('<script>alert')
  end

  scenario 'Comments prevent style tag with javascript URL' do
    article = create(:article, category: create(:category))

    sign_in_as(user)
    visit article_path(article)

    expect(page).to have_selector('#comment_text', wait: 5)

    fill_in 'comment_text', with: '[b]Text[/b]<style>body{background:url("javascript:alert(1)")}</style>'
    click_button I18n.t(:add_comment)

    # Verify style tag and javascript URL were stripped
    expect(page).not_to have_selector('style', visible: :all)
    expect(page.html).not_to include('javascript:')
    expect(page.html).not_to include('<style')
  end
end
