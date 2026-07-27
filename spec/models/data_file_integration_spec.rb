# frozen_string_literal: true

require 'rails_helper'

describe 'DataFile CarrierWave integration behavior' do
  before(:all) do
    @test_root = '/tmp/test_data_file_carrierwave'
    FileUtils.mkdir_p(@test_root)
  end

  after(:all) do
    FileUtils.rm_rf(@test_root)
  end

  before do
    # This spec must override the process-level root for isolated filesystem behavior.
    ENV['FILES_ROOT'] = @test_root
    FileUtils.mkdir_p(@test_root)

    # Ensure ROOT directory exists
    @root = Directory.find_or_create_by!(id: Directory::ROOT) do |dir|
      dir.name = 'root'
      dir.path = @test_root
      dir.title = 'Root'
      dir.hidden = false
    end
    @root.sync_inode_info if @root.st_dev.nil?
  end

  let(:root_directory) { @root }

  describe 'path caching after CarrierWave storage' do
    it 'caches correct path after file is stored' do
      dir_path = File.join(@test_root, 'uploads')
      FileUtils.mkdir_p(dir_path)

      directory = root_directory.subdirs.create!(name: 'uploads', path: dir_path, title: 'Uploads')
      directory.sync_inode_info

      # Create a test file
      source_file = File.join(@test_root, 'test_upload.txt')
      File.write(source_file, 'test content')

      # Upload using manual_upload
      datafile = DataFile.new(directory: directory)
      datafile.manual_upload(source_file)
      datafile.save!

      # After save, cached path should be the stored path, not a temp path
      expect(datafile.path).not_to be_empty
      # Path should contain the directory's relative path structure
      expect(datafile.path).to include('uploads/test_upload.txt')
      expect(File.exist?(datafile.path)).to be true
    end

    it 'updates cached path when CarrierWave destination changes' do
      dir1_path = File.join(@test_root, 'dir1')
      dir2_path = File.join(@test_root, 'dir2')
      FileUtils.mkdir_p([dir1_path, dir2_path])

      dir1 = root_directory.subdirs.create!(name: 'dir1', path: dir1_path, title: 'Dir 1')
      dir1.sync_inode_info
      dir2 = root_directory.subdirs.create!(name: 'dir2', path: dir2_path, title: 'Dir 2')
      dir2.sync_inode_info

      # Create and upload file
      source_file = File.join(@test_root, 'test.txt')
      File.write(source_file, 'content')

      datafile = DataFile.new(directory: dir1)
      datafile.manual_upload(source_file)
      datafile.save!

      old_path = datafile.path
      expect(old_path).to include('dir1')

      # Move file to different directory
      datafile.directory = dir2
      datafile.save!

      datafile.reload
      expect(datafile.path).to include('dir2')
      expect(datafile.path).not_to include('dir1')
    end
  end

  describe 'MD5 computation efficiency' do
    it 'computes MD5 using streaming to avoid loading entire file' do
      dir_path = File.join(@test_root, 'md5_test')
      FileUtils.mkdir_p(dir_path)

      directory = root_directory.subdirs.create!(name: 'md5test', path: dir_path, title: 'MD5')
      directory.sync_inode_info

      # Create a test file
      source_file = File.join(@test_root, 'large_file.bin')
      # Write 10MB of data
      File.open(source_file, 'wb') { |f| f.write('X' * (10 * 1024 * 1024)) }

      datafile = DataFile.new(directory: directory)
      datafile.manual_upload(source_file)
      datafile.save!

      # MD5 should be computed and stored
      expect(datafile.md5).to be_present
      expect(datafile.md5).to match(/\A[a-f0-9]{32}\z/)

      # Verify MD5 is correct using Digest::MD5.file
      expected_md5 = Digest::MD5.file(datafile.path).hexdigest
      expect(datafile.md5).to eq(expected_md5)
    end

    it 'detects when file is modified on disk' do
      dir_path = File.join(@test_root, 'change_test')
      FileUtils.mkdir_p(dir_path)

      directory = root_directory.subdirs.create!(name: 'changetest', path: dir_path, title: 'Change')
      directory.sync_inode_info

      source_file = File.join(@test_root, 'modifiable.txt')
      File.write(source_file, 'original')

      datafile = DataFile.new(directory: directory)
      datafile.manual_upload(source_file)
      datafile.save!

      original_md5 = datafile.md5

      # Modify the file on disk
      sleep(1.1) # Ensure timestamp changes
      File.write(datafile.path, 'modified content')

      # Should detect change
      expect(datafile.send(:file_changed_on_disk?)).to be true

      # Sync should update MD5 (using send to access private method)
      datafile.send(:sync_file_metadata)
      expect(datafile.md5).not_to eq(original_md5)
    end
  end

  describe 'directory changes trigger physical file moves' do
    it 'moves uploaded file when directory changes' do
      dir1_path = File.join(@test_root, 'source')
      dir2_path = File.join(@test_root, 'destination')
      FileUtils.mkdir_p([dir1_path, dir2_path])

      dir1 = root_directory.subdirs.create!(name: 'source', path: dir1_path, title: 'Source')
      dir1.sync_inode_info
      dir2 = root_directory.subdirs.create!(name: 'destination', path: dir2_path, title: 'Dest')
      dir2.sync_inode_info

      # Upload file
      source_file = File.join(@test_root, 'moveme.txt')
      File.write(source_file, 'move this')

      datafile = DataFile.new(directory: dir1)
      datafile.manual_upload(source_file)
      datafile.save!

      old_path = datafile.path
      expect(old_path).to include('source')
      expect(File.exist?(old_path)).to be true

      # Change directory
      datafile.directory = dir2
      datafile.save!

      # Old path should not exist
      expect(File.exist?(old_path)).to be false

      # New path should exist
      datafile.reload
      expect(datafile.path).to include('destination')
      expect(File.exist?(datafile.path)).to be true
    end
  end

  describe 'timestamp precision in file change detection' do
    it 'compares file timestamps at second precision' do
      dir_path = File.join(@test_root, 'precision_test')
      FileUtils.mkdir_p(dir_path)

      directory = root_directory.subdirs.create!(name: 'precisiontest', path: dir_path, title: 'Precision')
      directory.sync_inode_info

      source_file = File.join(@test_root, 'timestamp.txt')
      File.write(source_file, 'test')

      datafile = DataFile.new(directory: directory)
      datafile.manual_upload(source_file)
      datafile.save!

      original_mtime = File.mtime(datafile.path).to_i

      # Wait a full second before modifying
      sleep(1.1)
      File.write(datafile.path, 'modified')

      # After modification with sleep, timestamp should have changed
      new_mtime = File.mtime(datafile.path).to_i
      expect(new_mtime).to be > original_mtime

      # Now should detect change
      expect(datafile.send(:file_changed_on_disk?)).to be true
    end
  end
end
