# frozen_string_literal: true

require 'rails_helper'

feature 'User created servers', :js do
  let!(:user) { create :user }

  background do
    sign_in_as user
  end

  scenario 'Creating and updating a server' do
    visit new_server_path
    test_server_creation_and_editing

    expect(page).to have_text('192.168.1.2:8001')
  end
end
