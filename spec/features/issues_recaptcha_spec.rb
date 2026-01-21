require 'rails_helper'

RSpec.feature 'Issues reCAPTCHA', type: :feature do
  let!(:category) { create(:category, domain: Category::DOMAIN_ISSUES, name: 'TestIssues') }

  scenario 'anonymous user submits issue with valid reCAPTCHA' do
    allow_any_instance_of(ApplicationController).to receive(:verify_recaptcha).and_return(true)

    visit new_issue_path
    fill_in 'Title', with: 'Feature test issue'
    select 'TestIssues', from: 'Category'
    fill_in 'Text', with: 'This is a test issue body'
    expect do
      click_button 'Submit'
    end.to change { Issue.count }.by(1)

    expect(page).to have_content(I18n.t('issues_create'))
  end

  scenario 'anonymous user submits issue with invalid reCAPTCHA' do
    allow_any_instance_of(ApplicationController).to receive(:verify_recaptcha).and_return(false)

    visit new_issue_path
    fill_in 'Title', with: 'Feature test issue'
    select 'TestIssues', from: 'Category'
    fill_in 'Text', with: 'This is a test issue body'
    expect do
      click_button 'Submit'
    end.to_not(change { Issue.count })

    # form re-rendered with errors (render :new keeps the POST path)
    expect(page).to have_selector('form')
  end
end
