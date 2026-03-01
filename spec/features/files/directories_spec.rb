# frozen_string_literal: true

require 'rails_helper'

RSpec.feature 'Directories management', type: :feature, js: true do
  let!(:admin) { create(:user, :admin) }

  def ensure_root_directory!
    Directory.find_or_create_by!(id: Directory::ROOT) do |dir|
      dir.name = 'root'
      dir.title = 'Root'
      dir.hidden = false
      dir.path = ENV['FILES_ROOT']
      dir.parent = nil
    end
  end

  def open_directory_tab(directory)
    safe_click("#files-nav a[href='#dir_#{directory.id}']")
    expect(page).to have_css("#dir_#{directory.id}")
  end

  scenario 'visitor browses directory tabs and contents' do
    root = ensure_root_directory!
    parent = create(:directory, parent: root, title: 'Public Docs', description: 'Directory intro')
    child = create(:directory, parent: parent, title: 'Nested Docs')
    file = create(:data_file, directory: parent, title: 'Release Notes', description: 'Release notes text')

    visit directory_path(root)
    open_directory_tab(parent)

    within("#dir_#{parent.id}") do
      expect(page).to have_content('Directory intro')
      expect(page).to have_link(child.title)
      expect(page).to have_content(file.title)
      expect(page).to have_content('Release notes text')
      expect(page).not_to have_link('Edit Directory')
      expect(page).not_to have_link('Delete Directory')
      expect(page).not_to have_link('New Directory')
    end
  end

  scenario 'admin creates a new directory from directory controls' do
    root = ensure_root_directory!
    parent = create(:directory, parent: root, title: 'Create Parent')
    name = "uidir#{SecureRandom.hex(4)}"

    sign_in_via_session(admin)
    visit directory_path(root)
    open_directory_tab(parent)

    within("#dir_#{parent.id}") do
      click_link 'New Directory'
    end

    expect(page).to have_content('New directory')

    fill_in 'directory_name', with: name
    fill_in 'directory_title', with: 'Created via UI'
    fill_in 'directory_description', with: 'Created from feature spec'
    click_button 'Create Directory'

    expect(page).to have_content(I18n.t(:directories_create))

    created = Directory.find_by(name: name)
    expect(created).to be_present
    expect(created.parent_id).to eq(parent.id)
    expect(created.hidden).to eq(false)
    expect(File.directory?(created.full_path)).to be true
  end

  scenario 'admin edits directory title and description' do
    root = ensure_root_directory!
    directory = create(:directory, parent: root, title: 'Before Title', description: 'Before description')

    sign_in_via_session(admin)
    visit directory_path(root)
    open_directory_tab(directory)

    within("#dir_#{directory.id}") do
      click_link 'Edit Directory'
    end

    expect(page).to have_content('Editing directory')
    fill_in 'directory_title', with: 'After Title'
    fill_in 'directory_description', with: 'After description'
    click_button 'Update Directory'

    expect(page).to have_content(I18n.t(:directories_update))

    directory.reload
    expect(directory.title).to eq('After Title')
    expect(directory.description).to eq('After description')
  end

  scenario 'admin deletes a directory from directory controls' do
    root = ensure_root_directory!
    directory = create(:directory, parent: root, title: 'Delete Me')
    directory_path_on_disk = directory.full_path

    sign_in_via_session(admin)
    visit directory_path(root)
    open_directory_tab(directory)

    within("#dir_#{directory.id}") do
      accept_confirm do
        click_link 'Delete Directory'
      end
    end

    expect(page).to have_current_path(directory_path(root), ignore_query: true)
    expect(Directory.exists?(directory.id)).to be false
    expect(File.exist?(directory_path_on_disk)).to be false
  end

  scenario 'admin triggers reconcile from admin panel' do
    root = ensure_root_directory!

    reconcile_result = double(string: 'Reconciled from feature spec')
    reconcile_service = instance_double(DirectoryReconciliationService, call: reconcile_result)
    allow(DirectoryReconciliationService).to receive(:new).with(root).and_return(reconcile_service)

    sign_in_via_session(admin)
    visit about_adminpanel_path

    click_link 'Recreate Root'

    expect(page).to have_content(I18n.t(:directories_update))
    expect(page).to have_content('Reconciled from feature spec')
    expect(DirectoryReconciliationService).to have_received(:new).with(root)
  end
end
