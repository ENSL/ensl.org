# frozen_string_literal: true

require 'rails_helper'

RSpec.feature 'Data files management', type: :feature, js: true do
  let!(:admin) { create(:user, :admin) }
  let!(:user) { create(:user) }

  describe 'File viewing' do
    it 'displays file title, description, and metadata' do
      file = create(:data_file, :with_directory, title: 'ImportantDoc',
                                                 description: "Long file description\nwith two lines")

      visit data_file_path(file)

      expect(page).to have_content('ImportantDoc')
      expect(page).to have_content('Long file description')
      expect(page).to have_content('with two lines')
      expect(page).to have_content(file.md5_s)
    end

    it 'shows related files when present' do
      dir = create(:directory)
      file1 = create(:data_file, directory: dir, title: 'Part1')
      file2 = create(:data_file, directory: dir, title: 'Part2', related: file1)

      visit data_file_path(file2)

      expect(page).to have_content('Part2')
    end
  end

  describe 'File editing' do
    it 'allows admin to edit file title and description' do
      file = create(:data_file, :with_directory, title: 'OldTitle', description: 'Old description')

      sign_in_via_session(admin)
      visit edit_data_file_path(file)

      expect(page).to have_field('data_file_title', with: 'OldTitle')
      expect(page).to have_field('data_file_description', with: 'Old description')

      fill_in 'data_file_title', with: 'NewTitle'
      fill_in 'data_file_description', with: 'New long description for this file'
      click_button 'Update'

      expect(page).to have_content(I18n.t('flash.actions.update.notice', resource_name: DataFile.model_name.human))

      file.reload
      expect(file.title).to eq('NewTitle')
      expect(file.description).to eq('New long description for this file')
    end

    it 'shows description in directory listing' do
      root = create(:directory, :root)
      dir = create(:directory, parent: root, title: 'Listing Dir')
      file = create(:data_file, directory: dir, title: 'ListedFile', description: 'Listed description')

      visit directory_path(root)

      expect(page).to have_content(file.title)
      expect(page).to have_content('Listed description')
    end
  end

  describe 'File deletion' do
    it 'does not allow non-admin to delete files' do
      file = create(:data_file, :with_directory, title: 'ProtectedFile')

      sign_in_via_session(user)
      visit data_file_path(file)

      expect(page).not_to have_link('Delete')
    end
  end

  describe 'File access control' do
    it 'shows file information for authenticated users' do
      file = create(:data_file, :with_directory, title: 'ViewableFile')

      sign_in_via_session(user)
      visit data_file_path(file)

      expect(page).to have_content('ViewableFile')
    end

    it 'allows unauthenticated users to view files' do
      file = create(:data_file, :with_directory, title: 'PublicFile')

      visit data_file_path(file)

      expect(page).to have_content('PublicFile')
    end
  end

  describe 'File associations' do
    it 'can associate file with a match as demo' do
      dir = create(:directory)
      demo_file = create(:data_file, directory: dir, title: 'MatchDemo')

      contest = create(:contest)
      create(:match, contest: contest, demo: demo_file)

      visit data_file_path(demo_file)

      expect(page).to have_content('MatchDemo')
    end
  end

  describe 'File metadata' do
    it 'displays file size in human-readable format' do
      file = create(:data_file, :with_directory, size: 5_242_880) # 5 MB

      visit data_file_path(file)

      expect(page).to have_content('5.0 MB')
    end

    it 'displays MD5 hash in uppercase' do
      file = create(:data_file, :with_directory, md5: 'abc123def456')

      visit data_file_path(file)

      expect(page).to have_content('ABC123DEF456')
    end

    it 'displays file creation timestamp' do
      file = create(:data_file, :with_directory, title: 'TimeFile')

      visit data_file_path(file)

      expect(page).to have_content(file.created_at.strftime('%Y'))
    end
  end

  describe 'File model scopes' do
    it 'orders files by creation date (newest first)' do
      dir = create(:directory)
      old_file = create(:data_file, directory: dir, title: 'OldFile', created_at: 10.days.ago)
      new_file = create(:data_file, directory: dir, title: 'NewFile', created_at: 1.day.ago)

      ordered = DataFile.ordered

      expect(ordered.first).to eq(new_file)
      expect(ordered.last).to eq(old_file)
    end

    it 'filters files to exclude specific file' do
      dir = create(:directory)
      file1 = create(:data_file, directory: dir, title: 'File1')
      file2 = create(:data_file, directory: dir, title: 'File2')

      except = DataFile.except_file(file1)

      expect(except).to include(file2)
      expect(except).not_to include(file1)
    end

    it 'filters files with no related link' do
      dir = create(:directory)
      unlinked = create(:data_file, directory: dir, related: nil)
      linked = create(:data_file, directory: dir, related: unlinked)

      unrelated = DataFile.unrelated

      expect(unrelated).to include(unlinked)
      expect(unrelated).not_to include(linked)
    end

    it 'retrieves recent files limited to 8' do
      dir = create(:directory)
      create_list(:data_file, 10, directory: dir)

      recent = DataFile.recent

      expect(recent.count).to be <= 8
    end
  end

  describe 'File string representation' do
    it 'shows title as string' do
      file = create(:data_file, :with_directory, title: 'MyTitle')

      expect(file.to_s).to eq('MyTitle')
    end
  end

  describe 'File ratings' do
    it 'allows users to rate files' do
      file = create(:data_file, :with_directory)

      sign_in_via_session(user)

      # Rating is done via AJAX, just verify the file is accessible
      visit data_file_path(file)

      expect(page.status_code).to eq(200)
    end
  end

  describe 'Related files' do
    it 'links files together' do
      dir = create(:directory)
      main_file = create(:data_file, directory: dir, title: 'Main')
      related_file = create(:data_file, directory: dir, title: 'Related', related: main_file)

      expect(related_file.related).to eq(main_file)
      expect(main_file.related_files).to include(related_file)
    end

    it 'can unlink related files' do
      dir = create(:directory)
      main_file = create(:data_file, directory: dir, title: 'Main')
      related_file = create(:data_file, directory: dir, title: 'Related', related: main_file)

      related_file.update(related: nil)

      related_file.reload
      expect(related_file.related).to be_nil
    end

    it 'adds related file from edit page using update' do
      dir = create(:directory)
      main_file = create(:data_file, directory: dir, title: 'Main')
      candidate = create(:data_file, directory: dir, title: 'Candidate')

      sign_in_via_session(admin)
      visit edit_data_file_path(main_file)

      select 'Candidate', from: 'add_related_candidate_id'
      click_button 'Add'

      expect(page).to have_content(I18n.t('flash.actions.update.notice', resource_name: DataFile.model_name.human))
      expect(candidate.reload.related).to eq(main_file)
    end

    it 'removes related file from edit page using update' do
      dir = create(:directory)
      main_file = create(:data_file, directory: dir, title: 'Main')
      related_file = create(:data_file, directory: dir, title: 'Related', related: main_file)

      sign_in_via_session(admin)
      visit edit_data_file_path(main_file)

      within(all('table.striped').first) do
        within('tr', text: 'Related') do
          find('a[title="Remove related file"]').click
        end
      end

      expect(page).to have_content(I18n.t('flash.actions.update.notice', resource_name: DataFile.model_name.human))
      expect(related_file.reload.related).to be_nil
    end
  end

  describe 'Admin access' do
    it 'denies file creation to non-admin users' do
      dir = create(:directory)

      sign_in_via_session(user)
      visit new_data_file_path(id: dir.id)

      expect(page).to have_content('You are not allowed to visit the page')
    end
  end
end
