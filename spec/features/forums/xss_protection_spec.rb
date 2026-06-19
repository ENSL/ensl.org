# frozen_string_literal: true

require 'rails_helper'

feature 'XSS Protection in Forum Posts and Comments', js: true do
  let!(:user) { create(:user) }

  scenario 'Forum posts prevent script tag injection' do
    topic = create(:topic)

    sign_in_as(user)
    visit topic_path(topic)
    first(:link, 'Reply').click
    expect(page).to have_selector('#post_text', wait: 5)

    # Try to inject malicious content
    fill_in 'post_text', with: '[b]Safe post[/b]<script>alert("XSS")</script>'
    click_button 'Save Post'

    expect(page).to have_content('Safe post')

    # Verify script tag was stripped
    expect(page).not_to have_selector('script', text: 'alert', visible: :all)
    expect(page.html).not_to include('<script>alert')
  end

  scenario 'Forum posts prevent iframe injection' do
    topic = create(:topic)

    sign_in_as(user)
    visit topic_path(topic)
    first(:link, 'Reply').click
    expect(page).to have_selector('#post_text', wait: 5)

    fill_in 'post_text', with: '[b]Post[/b]<iframe src="http://evil.com"></iframe>'
    click_button 'Save Post'

    # Verify iframe was stripped
    expect(page).not_to have_selector('iframe', visible: :all)
    expect(page.html).not_to include('<iframe')
  end

  scenario 'Forum posts prevent event handler injection' do
    topic = create(:topic)

    sign_in_as(user)
    visit topic_path(topic)
    first(:link, 'Reply').click
    expect(page).to have_selector('#post_text', wait: 5)

    fill_in 'post_text', with: '[i]Text[/i]<img src=x onerror="alert(1)">'
    click_button 'Save Post'

    # Verify event handler was stripped
    expect(page.html).not_to include('onerror=')
    expect(page).to have_content('Text')
  end

  scenario 'Comments prevent script tag injection' do
    article = create(:article, user: create(:user, :admin), category: create(:category))
    Comment.create!(user: user, commentable: article, text: '[b]Safe comment[/b]<script>alert("XSS")</script>')

    sign_in_as(user)
    visit article_path(article)

    expect(page).to have_content('Safe comment')

    # Verify script tag was stripped
    expect(page).not_to have_selector('script', text: 'alert', visible: :all)
    expect(page.html).not_to include('<script>alert')
  end

  scenario 'Comments prevent style tag with javascript URL' do
    article = create(:article, user: create(:user, :admin), category: create(:category))
    Comment.create!(user: user, commentable: article,
                    text: '[b]Text[/b]<style>body{background:url("javascript:alert(1)")}</style>')

    sign_in_as(user)
    visit article_path(article)

    # Verify style tag and javascript URL were stripped
    within('#comments-thread') do
      expect(page).to have_content('Text')
      expect(page).not_to have_text('javascript:')
    end
  end
end
