# frozen_string_literal: true

require 'rails_helper'

feature 'Server Administration', js: true do
  let!(:admin) { create :user, :admin }

  background do
    sign_in_as admin
  end

  scenario 'creating a server' do
    visit servers_path
    expect(page).to have_content('Listing Servers')
    click_link 'New server'
    test_server_creation_and_editing
    visit servers_path
    expect(page).to have_content Server.last.name
  end

  feature 'Server deletion' do
    let!(:server) { create :server }
    scenario 'deleting a server' do
      visit servers_path
      expect(page).to have_content(server.name)
      visit server_path(server)
      click_link 'Delete Server'
      visit servers_path
      expect(page).to_not have_content(server.name)
    end
  end

  feature 'Server row expansion' do
    let!(:server) { create :server, description: 'Expand row test description' }

    scenario 'expanding a row reveals details, and collapsing hides them again' do
      visit servers_path

      row = find('tr.expand-row', text: server.name)
      expect(row['aria-expanded']).to eq('false')
      detail_id = row['data-expand-target']
      expect(page).to have_no_selector("##{detail_id}")

      row.find('strong', text: server.name).click

      expect(page).to have_selector("tr.expand-row[aria-expanded='true']", text: server.name)
      within("##{detail_id}") { expect(page).to have_content('Expand row test description') }

      find('tr.expand-row', text: server.name).find('strong', text: server.name).click

      expect(page).to have_selector("tr.expand-row[aria-expanded='false']", text: server.name)
      expect(page).to have_no_selector("##{detail_id}")
    end

    scenario 'clicking an interactive control inside the row does not toggle it' do
      visit servers_path

      row = find('tr.expand-row', text: server.name)
      within(row) { click_link 'Connect' }

      expect(page).to have_selector("tr.expand-row[aria-expanded='false']", text: server.name)
    end
  end
end
