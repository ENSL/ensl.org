# frozen_string_literal: true

require 'rails_helper'

RSpec.feature 'Broken files administration', :js, type: :feature do
  let!(:admin) { create(:user, :admin) }

  def ensure_root_directory!
    Directory.find_or_create_by!(id: Directory::ROOT) do |dir|
      dir.name = 'root'
      dir.title = 'Root'
      dir.hidden = false
      dir.path = Directory.files_root
    end
  end

  scenario 'admin removes checked broken files' do
    directory = create(:directory, parent: ensure_root_directory!)
    selected_file = create(:data_file, directory: directory, title: 'Remove this file',
                                       path: File.join(directory.full_path, 'remove-me.txt'))
    retained_file = create(:data_file, directory: directory, title: 'Keep this file',
                                       path: File.join(directory.full_path, 'keep-me.txt'))

    sign_in_via_session(admin)
    visit admin_data_files_path

    expect(page).to have_button('Remove checked files')
    expect(page).to have_css('.files-list-wrapper .files-list')

    within("#data_file_#{selected_file.id}") do
      find("input[name='file_ids[]'][value='#{selected_file.id}']").check
    end

    accept_confirm 'Remove the checked broken files?' do
      click_button 'Remove checked files', match: :first
    end

    expect(page).to have_current_path(admin_data_files_path)
    expect(page).to have_no_css("#data_file_#{selected_file.id}")
    expect(page).to have_css("#data_file_#{retained_file.id}")
    expect(DataFile.exists?(selected_file.id)).to be(false)
    expect(DataFile.exists?(retained_file.id)).to be(true)
  end
end
