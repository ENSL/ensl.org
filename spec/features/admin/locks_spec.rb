# frozen_string_literal: true

require 'rails_helper'

RSpec.feature 'Topic locks', type: :feature, js: true do
  let(:admin) { create(:user, :admin) }
  let(:user) { create(:user) }
  let!(:forum) { create(:forum) }
  let!(:topic) { create(:topic, forum: forum, user: user) }

  before do
  end

  scenario 'admin locks and unlocks a topic from the topic page' do
    sign_in_via_session(admin)
    visit topic_path(topic)

    expect(page).to have_link('Reply')
    expect(page).to have_link('Lock')

    click_link 'Lock'

    expect(page).to have_content(I18n.t(:topics_locked))
    expect(page).to have_link('Unlock')
    expect(page).not_to have_link('Lock')
    expect(page).not_to have_link('Reply')

    click_link 'Unlock'

    expect(page).to have_link('Lock')
    expect(page).not_to have_link('Unlock')
  end

  scenario 'regular user does not see lock controls' do
    sign_in_via_session(user)
    visit topic_path(topic)

    expect(page).not_to have_link('Lock')
    expect(page).not_to have_link('Unlock')
  end

  scenario 'forum topic list shows locked label' do
    Lock.create!(lockable: topic)

    sign_in_via_session(user)
    visit forum_path(forum)

    expect(page).to have_content('Locked:')
    expect(page).to have_link(topic.title)
  end
end
