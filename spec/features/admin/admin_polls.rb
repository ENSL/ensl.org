require 'rails_helper'

RSpec.feature 'Admin creates poll with options', type: :feature, js: true do
  scenario 'admin creates a poll with options via the admin UI' do
    Capybara.javascript_driver = :selenium_chrome_headless

    admin = FactoryBot.create(:user, :admin)
    sign_in_via_session(admin)

    # Go through the UI like a user: visit polls index and click New Poll
    visit '/polls/new'
    expect(page).to have_selector('form#new_poll')

    fill_in 'poll_question', with: 'Best Map?'

    # Fill the initial option
    first_option = all("input[name^='poll[options_attributes]'][name$='[option]']").first
    first_option.set('Dust2')

    # Use the Add an Option link to add another option via page JS
    click_link 'Add an Option'
    # Wait for the new field to appear
    expect(page).to have_selector("input[name$='[option]']", count: 2)
    all("input[name^='poll[options_attributes]'][name$='[option]']")[1].set('Inferno')

    click_button 'Save'

    # Ensure poll created
    expect(page).to have_content('Polls').or have_content('Poll was successfully created').or have_content('Best Map?')
    poll = Poll.order(:created_at).last
    expect(poll).not_to be_nil
    expect(poll.question).to eq('Best Map?')
    expect(poll.options.map(&:option)).to include('Dust2', 'Inferno')
  end

  scenario 'admin creates a poll and it shows on the main page with options' do
    Capybara.javascript_driver = :selenium_chrome_headless

    admin = FactoryBot.create(:user, :admin)
    sign_in_via_session(admin)

    # Go through the UI to create a poll
    visit '/polls/new'
    fill_in 'poll_question', with: 'Front Page Poll'
    first_option = all("input[name^='poll[options_attributes]'][name$='[option]']").first
    first_option.set('Alpha')
    click_link 'Add an Option'
    expect(page).to have_selector("input[name$='[option]']", count: 2)
    find_all("input[name^='poll[options_attributes]'][name$='[option]']", minimum: 2)[1].set('Beta')
    click_button 'Save'

    visit '/'

    expect(page).to have_content('Front Page Poll')
    expect(page).to have_content('Alpha')
    expect(page).to have_content('Beta')
  end

  scenario 'creating a poll with fewer than two options shows an error' do
    Capybara.javascript_driver = :selenium_chrome_headless

    admin = FactoryBot.create(:user, :admin)
    sign_in_via_session(admin)

    visit '/polls/new'
    expect(page).to have_content('New Poll')

    fill_in 'poll_question', with: 'Too Few Options'
    first_option = all("input[name^='poll[options_attributes]'][name$='[option]']").first
    first_option.set('OnlyOne')

    click_button 'Save'

    expect(page).to have_content('Poll must have at least two options')
    expect(Poll.where(question: 'Too Few Options').count).to eq(0)
  end
end
