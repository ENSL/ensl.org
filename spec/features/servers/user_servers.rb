require 'spec_helper'

feature 'User created servers' do
  let!(:user) { create :user }

  background do
    sign_in_as user
  end

  scenario 'Creating and updating a server' do
    visit new_server_path
    test_server_creation_and_editing
  end
end