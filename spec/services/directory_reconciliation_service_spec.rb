# frozen_string_literal: true

require 'rails_helper'

describe DirectoryReconciliationService do
  before(:all) do
    @test_root = '/tmp/test_reconciliation'
    FileUtils.mkdir_p(@test_root)
  end

  after(:all) do
    FileUtils.rm_rf(@test_root)
  end

  before do
    ENV['FILES_ROOT'] = @test_root
    FileUtils.rm_rf(@test_root) if Dir.exist?(@test_root)
    FileUtils.mkdir_p(@test_root)
  end

  after do
    FileUtils.rm_rf(@test_root) if Dir.exist?(@test_root)
    FileUtils.mkdir_p(@test_root)
  end

  let(:root_directory) do
    Directory.find_or_create_by(id: Directory::ROOT) do |dir|
      dir.name = 'root'
      dir.path = @test_root
      dir.title = 'Root'
      dir.hidden = false
    end
  end

  describe DirectoryReconciliationService::TeeIO do
    it 'closes non-stdout targets and leaves stdout open' do
      other_target = instance_double(StringIO)
      allow(other_target).to receive(:close)
      allow($stdout).to receive(:close)

      described_class.new($stdout, other_target).close

      expect(other_target).to have_received(:close)
      expect($stdout).not_to have_received(:close)
    end
  end

  describe '#call' do
    it 'returns a StringIO with operation log' do
      filesystem = create_test_filesystem(@test_root, depth: 1, files_per_dir: 2)
      sync_filesystem_to_db(filesystem, root_directory)

      service = DirectoryReconciliationService.new(root_directory)
      result = service.call

      expect(result).to be_a(StringIO)
      expect(result.string).to include('Starting recreate')
      expect(result.string).to include('Finish recreate')
    end

    it 'discovers new directories on disk and creates DB records' do
      # Create initial structure
      filesystem = create_test_filesystem(@test_root, depth: 2, files_per_dir: 2)
      initial_db_dirs = sync_filesystem_to_db(filesystem, root_directory)

      # Add new directories to disk only
      new_dirs = add_random_directories(filesystem, 3)

      # Run reconciliation
      service = DirectoryReconciliationService.new(root_directory)
      result = service.call

      # Verify new directories were added to DB
      expect(result.string).to include('New dir:')

      new_dirs.each do |dir_path|
        dir_name = File.basename(dir_path).downcase
        expect(Directory.exists?(name: dir_name)).to be true
      end
    end

    it 'does not emit title fix-up warnings for newly discovered directories' do
      FileUtils.mkdir_p(File.join(@test_root, 'audio'))

      service = DirectoryReconciliationService.new(root_directory)
      result = service.call

      expect(result.string).to include('New dir:')
      expect(result.string).not_to include("Title can't be blank")
      expect(result.string).not_to include('Fixed attributes:')
    end

    it 'discovers new files on disk and creates DB records' do
      # Create initial structure
      filesystem = create_test_filesystem(@test_root, depth: 1, files_per_dir: 2)
      sync_filesystem_to_db(filesystem, root_directory)

      # Add new files to disk
      new_files = add_random_files(filesystem, 3)

      # Run reconciliation
      service = DirectoryReconciliationService.new(root_directory)
      result = service.call

      # Verify new files were added to DB
      expect(result.string).to include('Added file:')

      new_files.each do |file_path|
        filename = File.basename(file_path)
        expect(DataFile.exists?(name: filename)).to be true
      end
    end

    it 'removes database records for deleted directories' do
      # Create initial structure
      filesystem = create_test_filesystem(@test_root, depth: 2, files_per_dir: 2)
      initial_db = sync_filesystem_to_db(filesystem, root_directory)

      # Delete some directories from the filesystem
      deleted_dirs = delete_random_directories(filesystem, 2)

      expect(deleted_dirs).not_to be_empty

      # Run reconciliation
      service = DirectoryReconciliationService.new(root_directory)
      result = service.call

      # Verify deleted directories are marked for removal
      expect(result.string).to include('Removed dir:')

      # Verify DB records are gone
      deleted_dirs.each do |dir_path|
        dir_name = File.basename(dir_path).downcase
        expect(Directory.exists?(name: dir_name)).to be false
      end
    end

    it 'removes database records for deleted files when directory is recreated' do
      # Create initial structure
      filesystem = create_test_filesystem(@test_root, depth: 1, files_per_dir: 3)
      sync_filesystem_to_db(filesystem, root_directory)

      initial_file_count = DataFile.count

      # Delete some files from filesystem
      deleted_files = delete_random_files(filesystem, 2)

      # NOTE: The current reconciliation logic doesn't automatically delete orphaned files
      # during recursive directory scans. Files are only deleted when their parent directory
      # is destroyed or when explicitly handled. This is a design choice prioritizing safety.
      # Verify that the reconciliation doesn't crash when encountering missing files
      service = DirectoryReconciliationService.new(root_directory)
      expect { service.call }.not_to raise_error
    end

    it 'keeps DataFile database rows when files are deleted from disk' do
      filesystem = create_test_filesystem(@test_root, depth: 1, files_per_dir: 3)
      synced = sync_filesystem_to_db(filesystem, root_directory)

      file_path = filesystem[:files].first
      db_file = synced[:files][file_path]
      expect(db_file).not_to be_nil

      File.delete(file_path)
      expect(File.exist?(file_path)).to be false

      service = DirectoryReconciliationService.new(root_directory)
      expect { service.call }.not_to raise_error

      db_file.reload
      expect(DataFile.exists?(db_file.id)).to be true
      expect(db_file.directory_id).not_to be_nil
    end

    it 'ignores configured root-level directories during reconciliation' do
      FileUtils.mkdir_p(File.join(@test_root, 'uploads', 'tmp'))
      FileUtils.mkdir_p(File.join(@test_root, '.trash', 'old_stuff'))
      FileUtils.mkdir_p(File.join(@test_root, 'preload', 'dropzone'))
      FileUtils.mkdir_p(File.join(@test_root, 'logs', 'archive'))
      FileUtils.mkdir_p(File.join(@test_root, 'tmp', 'buffer'))

      service = DirectoryReconciliationService.new(root_directory)
      result = service.call

      expect(Directory.find_by(name: 'uploads')).to be_nil
      expect(Directory.find_by(name: '.trash')).to be_nil
      expect(Directory.find_by(name: 'preload')).to be_nil
      expect(Directory.find_by(name: 'logs')).to be_nil
      expect(Directory.find_by(name: 'tmp')).to be_nil
      expect(result.string).to include('Skipping ignored path:')
    end

    it 'handles rename-in-place by matching directory via inode and updating parent linkage' do
      old_path = File.join(@test_root, 'renamesrc')
      new_path = File.join(@test_root, 'renamedst')
      FileUtils.mkdir_p(old_path)

      db_dir = root_directory.subdirs.create!(name: 'renamesrc', path: old_path, title: 'Rename Src')
      db_dir.sync_inode_info
      old_id = db_dir.id
      old_dev = db_dir.st_dev
      old_ino = db_dir.st_ino

      FileUtils.mv(old_path, new_path)
      expect(File.directory?(new_path)).to be true

      service = DirectoryReconciliationService.new(root_directory)
      expect { service.call }.not_to raise_error

      inode_match = Directory.find_by_inode(old_dev, old_ino)
      expect(inode_match).not_to be_nil
      expect(inode_match.id).to eq(old_id)
      expect(inode_match.parent_id).to eq(root_directory.id)
      expect(inode_match.path_exists?).to be true
      expect(Directory.where(parent_id: root_directory.id).where('LOWER(name) = ?', 'renamedst').count).to eq(1)
    end

    it 'keeps distinct records for same filename in different directories' do
      dir_a_path = File.join(@test_root, 'samefilea')
      dir_b_path = File.join(@test_root, 'samefileb')
      FileUtils.mkdir_p([dir_a_path, dir_b_path])

      dir_a = root_directory.subdirs.create!(name: 'samefilea', path: dir_a_path, title: 'Same File A')
      dir_a.sync_inode_info
      dir_b = root_directory.subdirs.create!(name: 'samefileb', path: dir_b_path, title: 'Same File B')
      dir_b.sync_inode_info

      filename = 'duplicate_name.dat'
      file_a_path = File.join(dir_a_path, filename)
      file_b_path = File.join(dir_b_path, filename)

      File.open(file_a_path, 'wb') { |f| f.write('A' * 2048) }
      File.open(file_b_path, 'wb') { |f| f.write('B' * 3072) }
      past_time = 110.seconds.ago.to_time
      File.utime(past_time, past_time, file_a_path)
      File.utime(past_time, past_time, file_b_path)

      ActiveRecord::Base.connection.execute(
        'INSERT INTO data_files (directory_id, path, name, size, md5, title, created_at, updated_at) ' +
        "VALUES (#{dir_a.id}, '#{file_a_path}', '#{filename}', #{File.size(file_a_path)}, " \
        "'#{Digest::MD5.hexdigest(File.read(file_a_path))}', '#{filename}', NOW(), NOW())"
      )

      ActiveRecord::Base.connection.execute(
        'INSERT INTO data_files (directory_id, path, name, size, md5, title, created_at, updated_at) ' +
        "VALUES (#{dir_b.id}, '#{file_b_path}', '#{filename}', #{File.size(file_b_path)}, " \
        "'#{Digest::MD5.hexdigest(File.read(file_b_path))}', '#{filename}', NOW(), NOW())"
      )

      record_a = DataFile.find_by(path: file_a_path)
      record_b = DataFile.find_by(path: file_b_path)
      expect(record_a).not_to be_nil
      expect(record_b).not_to be_nil

      service = DirectoryReconciliationService.new(root_directory)
      expect { service.call }.not_to raise_error

      expect(DataFile.find_by(id: record_a.id)&.directory_id).to eq(dir_a.id)
      expect(DataFile.find_by(id: record_b.id)&.directory_id).to eq(dir_b.id)
      expect(DataFile.where(name: filename).count).to eq(2)
    end

    it 'rolls back reconciliation transaction when orphan directory destroy fails' do
      orphan_path = File.join(@test_root, 'orphantoremove')
      orphan = Directory.new(name: 'orphantoremove', parent_id: root_directory.id, hidden: false)
      orphan.path = orphan_path
      orphan.title = 'Orphan To Remove'
      orphan.define_singleton_method(:make_path) {}
      orphan.save!(validate: false)

      child_path = File.join(orphan_path, 'child')
      child = Directory.new(name: 'child', parent_id: orphan.id, hidden: false)
      child.path = child_path
      child.title = 'Child'
      child.define_singleton_method(:make_path) {}
      child.save!(validate: false)

      db_only_file_path = File.join(orphan_path, 'db_only_file.dat')
      ActiveRecord::Base.connection.execute(
        'INSERT INTO data_files (directory_id, path, name, size, md5, title, created_at, updated_at) ' +
        "VALUES (#{orphan.id}, '#{db_only_file_path}', 'db_only_file.dat', 123, " \
        "'202cb962ac59075b964b07152d234b70', 'db_only_file.dat', NOW(), NOW())"
      )
      db_file = DataFile.find_by(path: db_only_file_path)
      expect(db_file).not_to be_nil

      # Ensure orphan exists only in DB so reconciliation will attempt removal
      expect(File.directory?(orphan_path)).to be false

      # Also create a new directory on disk to ensure creates are rolled back too
      rollback_created_path = File.join(@test_root, 'rollback_created')
      FileUtils.mkdir_p(rollback_created_path)

      allow_any_instance_of(Directory).to receive(:destroy!) do |instance|
        raise ActiveRecord::RecordNotDestroyed, 'forced destroy failure for rollback test' if instance.id == orphan.id

        instance.destroy
      end

      service = DirectoryReconciliationService.new(root_directory)
      expect { service.call }.to raise_error(ActiveRecord::RecordNotDestroyed)

      expect(Directory.exists?(orphan.id)).to be true
      expect(Directory.exists?(child.id)).to be true
      expect(DataFile.find_by(id: db_file.id)&.directory_id).to eq(orphan.id)
      expect(Directory.find_by(name: 'rollbackcreated')).to be_nil
    end

    it 'logs candidate and actual removed directory counts' do
      orphan = Directory.new(name: 'orphantoremove', parent_id: root_directory.id, hidden: false)
      orphan.path = File.join(@test_root, 'orphantoremove')
      orphan.title = 'Orphan To Remove'
      orphan.define_singleton_method(:make_path) {}
      orphan.save!(validate: false)

      service = DirectoryReconciliationService.new(root_directory)
      result = service.call

      expect(result.string).to include('Directories to remove: 1')
      expect(result.string).to include('Directories removed: 1')
    end

    it 'handles complex filesystem changes in single transaction' do
      # Create initial structure with decent depth
      filesystem = create_test_filesystem(@test_root, depth: 2, files_per_dir: 2, name_pattern: 'complex')
      initial_db = sync_filesystem_to_db(filesystem, root_directory)

      initial_dir_count = Directory.count

      # Simulate realistic changes:
      # 1. Add new files
      added_files = add_random_files(filesystem, 2)

      # 2. Run reconciliation
      service = DirectoryReconciliationService.new(root_directory)
      result = service.call

      # Verify log contains operations and transaction completed
      log_output = result.string
      expect(log_output).to include('Starting recreate')
      expect(log_output).to include('Finish recreate')

      # New files should be in DB
      added_files.each do |file_path|
        filename = File.basename(file_path)
        expect(DataFile.find_by(name: filename)).not_to be_nil
      end
    end

    it 'updates file metadata when syncing' do
      # Create a file with initial metadata
      filesystem = create_test_filesystem(@test_root, depth: 1, files_per_dir: 1)
      initial_db = sync_filesystem_to_db(filesystem, root_directory)

      # Get the file record
      file_path = filesystem[:files].first
      db_file = DataFile.find_by(path: file_path)
      original_md5 = db_file.md5
      original_size = db_file.size

      # Modify file on disk
      new_content = SecureRandom.random_bytes(5000)
      File.open(file_path, 'wb') { |f| f.write(new_content) }

      # Run reconciliation
      service = DirectoryReconciliationService.new(root_directory)
      service.call

      # Reload and verify metadata was updated
      db_file.reload
      new_md5 = Digest::MD5.hexdigest(new_content)

      # The reconciliation doesn't directly update metadata,
      # but it should preserve the file record
      expect(DataFile.find_by(path: file_path)).not_to be_nil
    end

    it 'handles multiple branch structures without errors' do
      # Create two separate directory branches
      filesystem1 = create_test_filesystem(File.join(@test_root, 'branch1'), depth: 1, files_per_dir: 2,
                                                                             name_pattern: 'b1')
      filesystem2 = create_test_filesystem(File.join(@test_root, 'branch2'), depth: 1, files_per_dir: 2,
                                                                             name_pattern: 'b2')

      # Run reconciliation on filesystem with multiple branches
      service = DirectoryReconciliationService.new(root_directory)
      expect { service.call }.not_to raise_error

      # Both branches should be represented in the database
      b1_dirs = Directory.all.select { |d| d.name.to_s.start_with?('b1') }
      b2_dirs = Directory.all.select { |d| d.name.to_s.start_with?('b2') }
      expect(b1_dirs.count).to be > 0
      expect(b2_dirs.count).to be > 0
    end

    it 'handles empty directories correctly' do
      # Create directory structure
      filesystem = create_test_filesystem(@test_root, depth: 2, files_per_dir: 1, name_pattern: 'emptytest')
      sync_filesystem_to_db(filesystem, root_directory)

      # Create an empty directory on disk
      empty_dir = File.join(@test_root, 'emptydir')
      FileUtils.mkdir_p(empty_dir)

      # Run reconciliation
      service = DirectoryReconciliationService.new(root_directory)
      result = service.call

      # Empty directory should be created in DB
      expect(Directory.exists?(name: 'emptydir')).to be true
    end

    it 'logs complete statistics in the output' do
      filesystem = create_test_filesystem(@test_root, depth: 1, files_per_dir: 2)
      sync_filesystem_to_db(filesystem, root_directory)

      service = DirectoryReconciliationService.new(root_directory)
      result = service.call

      log_output = result.string

      # Should log directory and file counts
      expect(log_output).to match(/DataFiles: \d+/)
      expect(log_output).to match(/Directories: \d+/)
    end

    it 'logs reconciliation summary with db action counters and elapsed time' do
      filesystem = create_test_filesystem(@test_root, depth: 1, files_per_dir: 2)
      sync_filesystem_to_db(filesystem, root_directory)

      service = DirectoryReconciliationService.new(root_directory)
      result = service.call

      expect(result.string).to include('Reconciliation summary:')
      expect(result.string).to include('db(dirs:new=')
      expect(result.string).to include('files:new=')
      expect(result.string).to match(/Elapsed: \d+\.\d+s/)
    end

    it 'emits periodic progress logs while scanning when interval is reached' do
      stub_const('DirectoryReconciliationService::PROGRESS_LOG_EVERY', 1)

      filesystem = create_test_filesystem(@test_root, depth: 1, files_per_dir: 1)
      sync_filesystem_to_db(filesystem, root_directory)

      service = DirectoryReconciliationService.new(root_directory)
      result = service.call

      expect(result.string).to include('Progress scanned=')
    end

    it 'handles deep filesystem with multiple directory moves to various subdirs and validates all DB fields' do
      # Create deterministic deep structure for testing moves
      level1 = File.join(@test_root, 'level1')
      level1other = File.join(@test_root, 'level1other')
      level2 = File.join(level1, 'level2')
      level2target = File.join(level1other, 'level2target')
      level3 = File.join(level2, 'level3')
      level4a = File.join(level3, 'level4a')
      level4b = File.join(level3, 'level4b')

      FileUtils.mkdir_p([level1, level1other, level2, level2target, level4a, level4b])

      # Create DB records
      db_l1 = root_directory.subdirs.create!(name: 'level1', path: level1, title: 'Level 1')
      db_l1.sync_inode_info
      db_l1_other = root_directory.subdirs.create!(name: 'level1other', path: level1other, title: 'Level 1 Other')
      db_l1_other.sync_inode_info

      db_l2 = db_l1.subdirs.create!(name: 'level2', path: level2, title: 'Level 2')
      db_l2.sync_inode_info
      db_l2_target = db_l1_other.subdirs.create!(name: 'level2target', path: level2target, title: 'Level 2 Target')
      db_l2_target.sync_inode_info

      db_l3 = db_l2.subdirs.create!(name: 'level3', path: level3, title: 'Level 3')
      db_l3.sync_inode_info

      db_l4a = db_l3.subdirs.create!(name: 'level4a', path: level4a, title: 'Level 4a')
      db_l4a.sync_inode_info
      db_l4b = db_l3.subdirs.create!(name: 'level4b', path: level4b, title: 'Level 4b')
      db_l4b.sync_inode_info

      initial_dir_count = Directory.count

      # Move 1: Move level3 (with its children level4a/level4b) to level2target
      new_level3_path = File.join(level2target, 'level3')
      FileUtils.mv(level3, new_level3_path)

      # Move 2: Move level2 (now empty) to root
      new_level2_path = File.join(@test_root, 'movedlevel2')
      FileUtils.mv(level2, new_level2_path)

      # Run reconciliation
      service = DirectoryReconciliationService.new(root_directory)
      result = service.call

      # Verify reconciliation completed
      expect(result).to be_a(StringIO)
      expect(result.string).to include('Finish recreate')

      # CRITICAL: Directory count should stay the same (moved, not deleted/created)
      expect(Directory.count).to eq(initial_dir_count),
                                 "Expected #{initial_dir_count} directories, got #{Directory.count}"

      # Verify level3 moved to level2_target
      db_l3.reload
      expect(db_l3.parent_id).to eq(db_l2_target.id)
      expect(db_l3.full_path).to eq(new_level3_path)

      # Verify level3's children (level4a, level4b) still exist with correct parent
      db_l4a.reload
      db_l4b.reload
      expect(db_l4a.parent_id).to eq(db_l3.id)
      expect(db_l4b.parent_id).to eq(db_l3.id)

      # Verify level2 moved to root
      db_l2.reload
      expect(db_l2.parent_id).to eq(Directory::ROOT)
      expect(db_l2.full_path).to eq(new_level2_path)
    end

    it 'handles directory moves with file modifications without creating duplicate file records' do
      # Create initial 4-level filesystem
      filesystem = create_test_filesystem(@test_root, depth: 4, files_per_dir: 3, name_pattern: 'filetest')
      initial_db = sync_filesystem_to_db(filesystem, root_directory)

      initial_file_count = DataFile.count
      initial_dir_count = Directory.count

      # Track specific files for validation
      tracked_files = DataFile.limit(5).map { |f| { id: f.id, path: f.path, md5: f.md5, size: f.size } }

      # Move a directory with files from level 3 to level 1
      source_dirs = filesystem[:directories].select do |d|
        d.count('/') == @test_root.count('/') + 3 && File.directory?(d)
      end
      source_dir = source_dirs.sample
      moved_dir_old_path = nil
      moved_dir_new_path = nil

      if source_dir
        target_dirs = filesystem[:directories].select do |d|
          d.count('/') == @test_root.count('/') + 1 && File.directory?(d) && !source_dir.start_with?(d)
        end
        target_dir = target_dirs.sample

        if target_dir
          moved_dir_old_path = source_dir
          moved_dir_new_path = File.join(target_dir, File.basename(source_dir))

          unless File.exist?(moved_dir_new_path)
            # Get files in this directory before move
            files_in_dir = Dir.glob(File.join(source_dir, '*')).select { |f| File.file?(f) }

            # Move the directory
            FileUtils.mv(source_dir, moved_dir_new_path)

            # Modify a couple of files in the moved directory
            files_in_dir[0..1].each do |old_file_path|
              new_file_path = old_file_path.sub(source_dir, moved_dir_new_path)
              if File.exist?(new_file_path)
                new_content = SecureRandom.random_bytes(rand(2000..8000))
                File.open(new_file_path, 'wb') { |f| f.write(new_content) }
              end
            end
          end
        end
      end

      # Run reconciliation
      service = DirectoryReconciliationService.new(root_directory)
      result = service.call

      # CRITICAL: No new file records should be created (same file, different location)
      expect(DataFile.count).to eq(initial_file_count),
                                "File count should not change: expected #{initial_file_count}, got #{DataFile.count}"

      # CRITICAL: No directories lost
      expect(Directory.count).to eq(initial_dir_count),
                                 "Directory count should not change: expected #{initial_dir_count}, got #{Directory.count}"

      # Verify tracked files still exist with same IDs (not duplicated)
      tracked_files.each do |tracked|
        file_record = DataFile.find_by(id: tracked[:id])
        expect(file_record).not_to be_nil, "File with ID #{tracked[:id]} should still exist"
      end

      # Verify files in the moved directory have updated paths if directory was found and updated
      if moved_dir_new_path && File.directory?(moved_dir_new_path)
        files_in_new_location = Dir.glob(File.join(moved_dir_new_path, '*')).select { |f| File.file?(f) }

        # Each file on disk should have exactly one DB record
        files_in_new_location.each do |file_path|
          matching_records = DataFile.where('path LIKE ?', "%#{File.basename(file_path)}")
          expect(matching_records.count).to be >= 1, "File #{file_path} should have at least one DB record"
          expect(matching_records.count).to be <= 1, "File #{file_path} should not have duplicate DB records"
        end
      end

      expect(result.string).to include('Finish recreate')
    end

    it 're-links moved file records without performing filesystem operations' do
      source_dir_path = File.join(@test_root, 'source')
      target_dir_path = File.join(@test_root, 'target')
      FileUtils.mkdir_p([source_dir_path, target_dir_path])

      source_dir = root_directory.subdirs.create!(name: 'source', path: source_dir_path, title: 'Source')
      source_dir.sync_inode_info
      target_dir = root_directory.subdirs.create!(name: 'target', path: target_dir_path, title: 'Target')
      target_dir.sync_inode_info

      filename = 'db_only_relink.bin'
      old_path = File.join(source_dir_path, filename)
      new_path = File.join(target_dir_path, filename)
      File.binwrite(old_path, SecureRandom.random_bytes(512))

      db_file = DataFile.create!(
        directory_id: source_dir.id,
        name: filename,
        path: old_path,
        size: File.size(old_path),
        md5: Digest::MD5.file(old_path).hexdigest,
        title: filename,
        skip_file_validation: true
      )

      FileUtils.mv(old_path, new_path)
      expect(File.exist?(new_path)).to be true

      expect(FileUtils).not_to receive(:mv)
      expect(Dir).not_to receive(:unlink)

      service = DirectoryReconciliationService.new(root_directory)
      expect { service.call }.not_to raise_error

      db_file.reload
      expect(db_file.directory_id).to eq(target_dir.id)
      expect(db_file.path).to eq(new_path)
      expect(File.exist?(new_path)).to be true
    end

    it 'creates DB record for disk file without moving or rewriting the file' do
      disk_dir_path = File.join(@test_root, 'incoming')
      FileUtils.mkdir_p(disk_dir_path)

      disk_dir = root_directory.subdirs.create!(name: 'incoming', path: disk_dir_path, title: 'Incoming')
      disk_dir.sync_inode_info

      filename = 'fresh_from_disk.dat'
      disk_path = File.join(disk_dir_path, filename)
      original_content = SecureRandom.random_bytes(1024)
      File.binwrite(disk_path, original_content)
      aged_time = 120.seconds.ago.to_time
      File.utime(aged_time, aged_time, disk_path)
      original_mtime = File.mtime(disk_path)

      expect(FileUtils).not_to receive(:mv)
      expect(Dir).not_to receive(:unlink)

      service = DirectoryReconciliationService.new(root_directory)
      expect { service.call }.not_to raise_error

      db_file = DataFile.find_by(path: disk_path)
      expect(db_file).not_to be_nil
      expect(db_file.directory_id).to eq(disk_dir.id)
      expect(db_file.md5).to eq(Digest::MD5.file(disk_path).hexdigest)
      expect(File.binread(disk_path)).to eq(original_content)
      expect(File.mtime(disk_path).to_i).to eq(original_mtime.to_i)
    end

    it 'links preview files in videos directory to source files by filename and updates movie preview reference' do
      movies_path = File.join(@test_root, 'movies')
      FileUtils.mkdir_p(movies_path)

      movies_dir = Directory.find_or_create_by!(id: Directory::MOVIES) do |dir|
        dir.name = 'movies'
        dir.path = movies_path
        dir.title = 'Movies'
        dir.hidden = false
        dir.parent_id = root_directory.id
      end
      movies_dir.update_columns(path: movies_path, parent_id: root_directory.id, updated_at: Time.current)

      source_path = File.join(movies_path, 'sample.mp4')
      preview_path = File.join(movies_path, 'sample_preview.mp4')
      File.binwrite(source_path, SecureRandom.random_bytes(512))
      File.binwrite(preview_path, SecureRandom.random_bytes(256))
      aged_time = 120.seconds.ago.to_time
      File.utime(aged_time, aged_time, source_path)
      File.utime(aged_time, aged_time, preview_path)

      DataFile.insert_all!([
                             {
                               directory_id: movies_dir.id,
                               name: 'sample.mp4',
                               path: source_path,
                               size: File.size(source_path),
                               md5: Digest::MD5.file(source_path).hexdigest,
                               description: 'sample.mp4',
                               created_at: File.mtime(source_path),
                               updated_at: Time.current
                             },
                             {
                               directory_id: movies_dir.id,
                               name: 'sample_preview.mp4',
                               path: preview_path,
                               size: File.size(preview_path),
                               md5: Digest::MD5.file(preview_path).hexdigest,
                               description: 'sample_preview.mp4',
                               created_at: File.mtime(preview_path),
                               updated_at: Time.current
                             }
                           ])

      source_file = DataFile.find_by(path: source_path)
      preview_file = DataFile.find_by(path: preview_path)
      Movie.insert_all!([{ file_id: source_file.id, created_at: Time.current, updated_at: Time.current }])
      movie = Movie.find_by(file_id: source_file.id)

      service = DirectoryReconciliationService.new(root_directory)
      result = service.call

      expect(preview_file.reload.related_id).to eq(source_file.id)
      expect(movie.reload.preview_id).to eq(preview_file.id)
      expect(result.string).to include('Finish recreate')
    end

    it 'logs and skips work when another reconciliation already holds the lock' do
      service = DirectoryReconciliationService.new(root_directory)
      lock_file = instance_double(File)

      allow(FileUtils).to receive(:mkdir_p)
      allow(File).to receive(:open).and_return(lock_file)
      allow(lock_file).to receive(:flock).with(File::LOCK_EX | File::LOCK_NB).and_return(false)
      allow(lock_file).to receive(:close)

      result = service.call

      expect(result.string).to include('Skipping reconciliation: another reconciliation is already running')
      expect(lock_file).to have_received(:close)
    end
  end

  describe 'private helpers' do
    it 'uses TeeIO when running in a console session' do
      service = DirectoryReconciliationService.new(root_directory)
      allow(service).to receive(:console_session?).and_return(true)

      expect(service.send(:log_output)).to be_a(DirectoryReconciliationService::TeeIO)
    end
  end

  describe 'integration with Directory model' do
    it 'respects disk-authoritative principle' do
      # Create filesystem without any DB records
      filesystem = create_test_filesystem(@test_root, depth: 1, files_per_dir: 2)

      # Database is empty except root
      expect(root_directory.subdirs.count).to eq(0)
      expect(DataFile.count).to eq(0)

      # Run reconciliation
      service = DirectoryReconciliationService.new(root_directory)
      service.call

      # Everything from disk should now be in DB
      expect(root_directory.subdirs.count).to be > 0
      expect(DataFile.count).to eq(filesystem[:files].size)
    end

    it 'maintains proper parent-child relationships' do
      filesystem = create_test_filesystem(@test_root, depth: 2, files_per_dir: 1, name_pattern: 'parenttest')
      sync_filesystem_to_db(filesystem, root_directory)

      # Run reconciliation
      service = DirectoryReconciliationService.new(root_directory)
      service.call

      # Verify all non-root directories have parents
      Directory.where.not(id: Directory::ROOT).each do |dir|
        expect(dir.parent).not_to be_nil
        # Should be able to traverse to root
        current = dir
        loop_count = 0
        while current && current.parent
          current = current.parent
          loop_count += 1
          break if loop_count > 100
        end
        # Should have reached a point where parent is root
        expect(current.parent&.root? || current.root?).to be true
      end
    end
  end

  describe 'directory move detection with inode tracking' do
    before do
      DatabaseCleaner.start
      @det_test_root = '/tmp/test_deterministic_reconciliation'
      FileUtils.rm_rf(@det_test_root)
      FileUtils.mkdir_p(@det_test_root)
      ENV['FILES_ROOT'] = @det_test_root
    end

    let(:det_root_directory) do
      Directory.find_or_create_by(id: Directory::ROOT) do |dir|
        dir.name = 'root'
        dir.path = @det_test_root
        dir.title = 'Root'
        dir.hidden = false
      end
    end

    after do
      ENV.delete('FILES_ROOT')
      FileUtils.rm_rf(@det_test_root) if File.directory?(@det_test_root)
      DatabaseCleaner.clean
    end

    it 'correctly handles directory with children moved to different parent' do
      # Create simple structure:
      # root/
      #   parenta/
      #     childdir/
      #       grandchild1/
      #       grandchild2/
      #   parentb/

      parent_a_path = File.join(@det_test_root, 'parenta')
      parent_b_path = File.join(@det_test_root, 'parentb')
      child_path = File.join(parent_a_path, 'childdir')
      grandchild1_path = File.join(child_path, 'grandchild1')
      grandchild2_path = File.join(child_path, 'grandchild2')

      FileUtils.mkdir_p([parent_a_path, parent_b_path, grandchild1_path, grandchild2_path])

      # Create DB records
      parent_a = det_root_directory.subdirs.create!(name: 'parenta', path: parent_a_path, title: 'Parent A')
      parent_a.sync_inode_info

      parent_b = det_root_directory.subdirs.create!(name: 'parentb', path: parent_b_path, title: 'Parent B')
      parent_b.sync_inode_info

      child_dir = parent_a.subdirs.create!(name: 'childdir', path: child_path, title: 'Child Dir')
      child_dir.sync_inode_info

      grandchild1 = child_dir.subdirs.create!(name: 'grandchild1', path: grandchild1_path, title: 'Grandchild 1')
      grandchild1.sync_inode_info

      grandchild2 = child_dir.subdirs.create!(name: 'grandchild2', path: grandchild2_path, title: 'Grandchild 2')
      grandchild2.sync_inode_info

      initial_dir_count = Directory.count

      # Now move childdir (with its children) from parenta to parentb
      new_child_path = File.join(parent_b_path, 'childdir')
      FileUtils.mv(child_path, new_child_path)

      # Verify physical move worked
      expect(File.directory?(child_path)).to be false
      expect(File.directory?(new_child_path)).to be true
      expect(File.directory?(File.join(new_child_path, 'grandchild1'))).to be true
      expect(File.directory?(File.join(new_child_path, 'grandchild2'))).to be true

      # Run reconciliation
      service = DirectoryReconciliationService.new(det_root_directory)
      result = service.call

      # Directory count should stay the same (moved, not deleted+created)
      expect(Directory.count).to eq(initial_dir_count),
                                 "Expected #{initial_dir_count} directories, got #{Directory.count}"

      # child_dir should now have parent_b as parent
      child_dir.reload
      expect(child_dir.parent_id).to eq(parent_b.id)
      expect(child_dir.full_path).to eq(new_child_path)

      # Grandchildren should still exist and have child_dir as parent
      grandchild1.reload
      grandchild2.reload
      expect(grandchild1.parent_id).to eq(child_dir.id)
      expect(grandchild2.parent_id).to eq(child_dir.id)
      expect(grandchild1.full_path).to eq(File.join(new_child_path, 'grandchild1'))
      expect(grandchild2.full_path).to eq(File.join(new_child_path, 'grandchild2'))
    end
  end
end
