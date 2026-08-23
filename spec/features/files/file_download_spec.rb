# frozen_string_literal: true

require 'rails_helper'

RSpec.feature 'Uploaded file downloads', type: :feature do
  let!(:admin) { create(:user, :admin) }

  before do
    allow(Directory).to receive(:files_root).and_return(Rails.public_path.join('files').to_s)
  end

  after do
    FileUtils.rm_rf(@directory.full_path) if @directory
  end

  scenario 'an uploaded file is downloadable from its public URL' do
    @directory = create(:directory, parent: create(:directory, :root))
    upload = Tempfile.new(['download-pipeline', '.txt'])
    upload.write('download pipeline content')
    upload.close

    sign_in_as(admin)
    visit new_data_file_path(id: @directory.id)
    attach_file 'data_file_name', upload.path
    fill_in 'data_file_title', with: 'Pipeline upload'
    select @directory.path, from: 'data_file_directory_id'
    click_button 'Create File'

    created = DataFile.find_by!(title: 'Pipeline upload')
    expect(File.binread(created.location)).to eq('download pipeline content')
    expect(page).to have_content(I18n.t('flash.actions.create.notice', resource_name: DataFile.model_name.human))

    click_link 'Download'
    expect(page.status_code).to eq(200)
    expect(page.body).to eq('download pipeline content')
  ensure
    upload&.unlink
  end

  scenario 'a failed production download check warns without failing creation' do
    @directory = create(:directory, parent: create(:directory, :root))
    upload = Tempfile.new(['download-warning', '.txt'])
    upload.write('stored despite failed check')
    upload.close
    allow(DataFile).to receive(:public_download_origin).and_return('https://www.example.test')
    allow_any_instance_of(DataFile).to receive(:downloadable_from?).and_return(false)

    sign_in_as(admin)
    visit new_data_file_path(id: @directory.id)
    attach_file 'data_file_name', upload.path
    fill_in 'data_file_title', with: 'Warning upload'
    select @directory.path, from: 'data_file_directory_id'
    click_button 'Create File'

    expect(page).to have_content(I18n.t('flash.actions.create.notice', resource_name: DataFile.model_name.human))
    expect(page).to have_content('File uploaded successfully, but its download URL is not currently reachable.')
    expect(DataFile.find_by(title: 'Warning upload')).to be_present
  ensure
    upload&.unlink
  end
end
