# frozen_string_literal: true

# == Schema Information
#
# Table name: directories
#
#  id          :integer          not null, primary key
#  description :string(255)
#  hidden      :boolean          default(FALSE), not null
#  name        :string(255)
#  path        :string(255)
#  title       :string(255)
#  created_at  :datetime
#  updated_at  :datetime
#  parent_id   :integer
#
# Indexes
#
#  index_directories_on_parent_id  (parent_id)
#

require 'rails_helper'

describe Directory do
  # Setup and cleanup test filesystem
  before(:all) do
    @test_root = '/tmp/test_directories'
    FileUtils.mkdir_p(@test_root)
  end

  after(:all) do
    FileUtils.rm_rf(@test_root)
  end

  before do
    # Set up test root environment
    ENV['FILES_ROOT'] = @test_root
  end

  after do
    # Clean up test directories
    FileUtils.rm_rf(@test_root) if Dir.exist?(@test_root)
    FileUtils.mkdir_p(@test_root)
  end

  describe 'associations' do
    subject { build(:directory) }

    it { is_expected.to belong_to(:parent).optional }
    it { is_expected.to have_many(:subdirs) }
    it { is_expected.to have_many(:files) }
  end

  describe 'validations' do
    subject { build(:directory) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_least(1).is_at_most(255) }
    it { is_expected.to validate_length_of(:path).is_at_most(255) }
    it { is_expected.to validate_length_of(:description).is_at_most(255) }

    # Simply validate that title validation exists
    it 'validates title presence when explicitly nil' do
      # Don't trigger ensure_path_cached by not having a parent and not providing attributes
      # Create directory skipping callbacks to test validation only
      dir = Directory.new(name: 'test', hidden: false, title: nil)
      # Manually set path to avoid the auto-setting triggering title auto-generation
      dir.path = '/some/path'
      dir.validate
      # Reset title to nil after path callback might have set it
      dir.title = nil
      dir.validate
      expect(dir.errors[:title]).to include("can't be blank")
    end

    describe 'name format validation' do
      it 'accepts alphanumeric names' do
        dir = build(:directory, name: 'Test123')
        expect(dir).to be_valid
      end

      it 'rejects names with special characters on create' do
        dir = build(:directory, name: 'test-dir')
        expect(dir).not_to be_valid
      end

      it 'rejects names longer than 20 characters on create' do
        dir = build(:directory, name: 'a' * 21)
        expect(dir).not_to be_valid
      end

      it 'rejects blocked names at root level' do
        root = create(:directory, :root, path: @test_root)
        dir = build(:directory, name: 'tmp', parent: root)

        expect(dir).not_to be_valid
        expect(dir.errors[:name]).to include('is reserved at root level')
      end

      it 'allows blocked names outside root level' do
        root = create(:directory, :root, path: @test_root)
        level_one = create(:directory, name: 'levelone', parent: root)
        dir = build(:directory, name: 'tmp', parent: level_one)

        expect(dir).to be_valid
      end
    end

    # Path is now auto-cached from full_path in before_validation callback
    # No need to validate that they match since we set it automatically
  end

  describe 'scopes' do
    describe '.ordered' do
      it 'returns directories ordered by name ASC' do
        dir_b = create(:directory, name: 'bravo')
        dir_a = create(:directory, name: 'alpha')
        dir_c = create(:directory, name: 'charlie')

        result = Directory.ordered
        expect(result.pluck(:name)).to eq(%w[alpha bravo charlie])
      end
    end

    describe '.path_sorted' do
      it 'returns directories ordered by path ASC' do
        dir1 = create(:directory, path: "#{@test_root}/zebra")
        dir2 = create(:directory, path: "#{@test_root}/apple")
        dir3 = create(:directory, path: "#{@test_root}/middle")

        result = Directory.path_sorted
        expect(result.first).to eq(dir2)
        expect(result.last).to eq(dir1)
      end
    end

    describe '.filtered' do
      it 'returns only non-hidden directories' do
        visible = create(:directory, hidden: false)
        hidden = create(:directory, hidden: true)

        result = Directory.filtered
        expect(result).to include(visible)
        expect(result).not_to include(hidden)
      end
    end

    describe '.of_parent' do
      it 'returns directories with specified parent' do
        parent = create(:directory)
        child1 = create(:directory, parent: parent)
        child2 = create(:directory, parent: parent)
        other = create(:directory)

        result = Directory.of_parent(parent)
        expect(result).to include(child1, child2)
        expect(result).not_to include(other)
      end
    end
  end

  describe 'constants' do
    it 'defines ROOT constant' do
      expect(Directory::ROOT).to eq(1)
    end

    it 'defines DEMOS constant' do
      expect(Directory::DEMOS).to eq(5)
    end

    it 'defines MOVIES constant' do
      expect(Directory::MOVIES).to eq(30)
    end

    it 'defines ARTICLES constant' do
      expect(Directory::ARTICLES).to eq(39)
    end
  end

  describe '#to_s' do
    it 'returns the directory name' do
      dir = build(:directory, name: 'testdir')
      expect(dir.to_s).to eq('testdir')
    end
  end

  describe '#parent_root?' do
    it 'returns true when parent is ROOT directory' do
      root = create(:directory, id: Directory::ROOT, path: @test_root)
      dir = build(:directory, parent: root)
      expect(dir.parent_root?).to be true
    end

    it 'returns false when parent is not ROOT' do
      parent = create(:directory, id: Directory::ROOT + 200)
      dir = build(:directory, parent: parent)
      expect(dir.parent_root?).to be false
    end

    it 'returns false when there is no parent' do
      dir = build(:directory, parent: nil)
      expect(dir.parent_root?).to be false
    end
  end

  describe '#root?' do
    it 'returns true when id is ROOT' do
      dir = build(:directory, id: Directory::ROOT)
      expect(dir.root?).to be true
    end

    it 'returns false when id is not ROOT' do
      dir = build(:directory, id: 999)
      expect(dir.root?).to be false
    end
  end

  describe '#preserve_files?' do
    it 'returns true when preserve_files is set to true' do
      dir = build(:directory)
      dir.preserve_files = true
      expect(dir.preserve_files?).to be true
    end

    it 'returns false when preserve_files is not set' do
      dir = build(:directory)
      expect(dir.preserve_files?).to be false
    end
  end

  describe '#move_to_trash?' do
    it 'returns true when move_to_trash is set to true' do
      dir = build(:directory)
      dir.move_to_trash = true

      expect(dir.move_to_trash?).to be true
    end

    it 'returns false when move_to_trash is not set' do
      expect(build(:directory).move_to_trash?).to be false
    end
  end

  describe '#full_path' do
    it 'returns path for root directory' do
      dir = build(:directory, path: @test_root, parent: nil)
      expect(dir.full_path).to eq(@test_root)
    end

    it 'returns joined path for child directory' do
      parent = create(:directory, id: Directory::ROOT + 100, name: 'parent')
      child = build(:directory, name: 'child', parent: parent)
      expect(child.full_path).to eq("#{@test_root}/parent/child")
    end

    it 'returns nested path for deep hierarchy' do
      parent = create(:directory, id: Directory::ROOT + 101, name: 'level1')
      middle = create(:directory, name: 'level2', parent: parent)
      child = build(:directory, name: 'level3', parent: middle)
      expect(child.full_path).to eq("#{@test_root}/level1/level2/level3")
    end
  end

  describe '#relative_path' do
    it 'returns empty string for root directory' do
      dir = build(:directory, id: Directory::ROOT, name: 'root', parent: nil)
      expect(dir.relative_path).to eq('')
    end

    it 'returns relative path for child directory' do
      parent = create(:directory, name: 'parent')
      child = build(:directory, name: 'child', parent: parent)
      # Assuming parent's relative_path is 'parent'
      expect(child.relative_path).to match(/child/)
    end
  end

  describe '#full_title' do
    it 'returns title for root directory' do
      dir = Directory.new(id: Directory::ROOT, name: 'test', title: 'Test Directory', path: @test_root, parent: nil,
                          hidden: false)
      dir.save!(validate: false)
      # directory_traverse returns empty list for root
      # So full_title returns empty string for root directories
      expect(dir.full_title).to eq('')
    end

    it 'joins titles with » for nested directories' do
      root = create(:directory, id: Directory::ROOT, title: 'Root', path: @test_root, parent: nil)
      parent = create(:directory, name: 'parent', title: 'Parent', parent: root)
      child = create(:directory, name: 'child', title: 'Child', parent: parent)

      expect(child.full_title).to eq('Parent » Child')
    end

    it 'uses name when title is blank' do
      root = create(:directory, id: Directory::ROOT, title: 'Root', path: @test_root, parent: nil)
      parent = Directory.new(name: 'parent', title: '', parent: root, hidden: false)
      parent.path = "#{@test_root}/parent"
      parent.save!(validate: false)

      expect(parent.full_title).to eq('parent')
    end
  end

  describe '#path_exists?' do
    it 'returns true when directory exists on filesystem' do
      dir_path = "#{@test_root}/existing"
      FileUtils.mkdir_p(dir_path)
      dir = Directory.new(path: dir_path, name: 'existing', hidden: false)
      expect(dir.path_exists?).to be true
    end

    it 'returns false when directory does not exist' do
      # Use Directory.new to avoid factory creating the path
      dir = Directory.new(path: "#{@test_root}/nonexistent", name: 'nonexistent', hidden: false)
      expect(dir.path_exists?).to be false
    end
  end

  describe '.directory_traverse' do
    it 'returns empty list for root directory' do
      root = create(:directory, id: Directory::ROOT, path: @test_root)
      result = Directory.directory_traverse(root)
      expect(result).to eq([])
    end

    it 'returns path to root for nested directory' do
      root = create(:directory, id: Directory::ROOT, path: @test_root)
      parent = create(:directory, name: 'parent', parent: root)
      child = create(:directory, name: 'child', parent: parent)

      result = Directory.directory_traverse(child)
      expect(result).to include(child, parent)
      expect(result).not_to include(root)
    end
  end

  describe 'callbacks' do
    describe 'before_validation :init_variables' do
      it 'sets path from parent when parent exists' do
        parent = create(:directory, id: Directory::ROOT + 102, name: 'parent')
        child = build(:directory, name: 'child', parent: parent)
        child.valid?
        expect(child.path).to eq("#{@test_root}/parent/child")
      end

      it 'capitalizes title from path basename' do
        dir = Directory.new(path: "#{@test_root}/mytest", name: 'mytest', hidden: false)
        dir.valid?
        expect(dir.title).to eq('Mytest')
      end

      it 'sets hidden to false when nil' do
        dir = build(:directory, hidden: nil)
        dir.valid?
        expect(dir.hidden).to be false
      end
    end

    describe 'after_create :make_path' do
      it 'creates directory on filesystem' do
        dir = create(:directory, name: 'newdir')
        expect(File.directory?(dir.full_path)).to be true
      end

      it 'does not fail if directory already exists' do
        dir_name = 'existing'
        # Create the directory on disk first
        dir_path = File.join(@test_root, dir_name)
        FileUtils.mkdir_p(dir_path)

        # Creating a record for existing directory should not fail
        # make_path callback handles this gracefully
        expect { create(:directory, name: dir_name) }.not_to raise_error
      end
    end

    describe 'after_save :update_timestamp' do
      it 'updates created_at from filesystem mtime' do
        dir = create(:directory, name: 'timestamptest')
        # Set a specific time - convert to Time object
        past_time = 2.days.ago.to_time
        File.utime(past_time, past_time, dir.full_path)

        # Trigger update_timestamp by re-saving
        dir.save!
        dir.reload
        expect(dir.created_at).to be_within(2.seconds).of(past_time)
      end
    end

    describe 'before_destroy :remove_files' do
      it 'destroys all files in directory' do
        dir = create(:directory)
        # Use raw SQL to insert data files without triggering callbacks
        file1_id = ActiveRecord::Base.connection.insert(
          'INSERT INTO data_files (directory_id, path, md5, size, created_at, updated_at) ' +
          "VALUES (#{dir.id}, '/tmp/file1.txt', 'abc123', 100, NOW(), NOW())"
        )
        file2_id = ActiveRecord::Base.connection.insert(
          'INSERT INTO data_files (directory_id, path, md5, size, created_at, updated_at) ' +
          "VALUES (#{dir.id}, '/tmp/file2.txt', 'def456', 200, NOW(), NOW())"
        )

        dir.destroy
        expect(DataFile.exists?(file1_id)).to be false
        expect(DataFile.exists?(file2_id)).to be false
      end

      it 'destroys all subdirectories' do
        parent = create(:directory)
        child1 = create(:directory, parent: parent)
        child2 = create(:directory, parent: parent)

        parent.destroy
        expect(Directory.exists?(child1.id)).to be false
        expect(Directory.exists?(child2.id)).to be false
      end

      it 'skips removal when preserve_files is true' do
        dir = create(:directory)
        # Use direct SQL to avoid any callbacks
        ActiveRecord::Base.connection.execute(
          'INSERT INTO data_files (directory_id, path, md5, size, created_at, updated_at) ' +
          "VALUES (#{dir.id}, '/tmp/file.txt', 'abc123', 100, NOW(), NOW())"
        )
        file_id = ActiveRecord::Base.connection.select_value('SELECT LAST_INSERT_ID()')

        dir.preserve_files = true
        dir.destroy

        # Check if the record still exists
        result = ActiveRecord::Base.connection.select_value(
          "SELECT COUNT(*) FROM data_files WHERE id = #{file_id}"
        )
        expect(result).to eq(1)
      end

      it 'moves directory to trash when move_to_trash is true' do
        dir = create(:directory)
        File.write(File.join(dir.full_path, 'example.txt'), 'trash me')

        dir.move_to_trash = true
        dir.destroy

        trash_root = dir.send(:trash_root_for, dir.full_path)
        matches = Dir.glob(File.join(trash_root, "#{File.basename(dir.full_path)}_*"))
        expect(File.exist?(dir.full_path)).to be false
        expect(matches).not_to be_empty
      end
    end

    describe 'after_destroy :remove_path' do
      it 'removes directory from filesystem' do
        dir = create(:directory, name: 'removeme')
        dir_path = dir.full_path
        expect(File.directory?(dir_path)).to be true

        dir.destroy
        expect(File.directory?(dir_path)).to be false
      end
    end
  end

  describe 'reconciliation via service' do
    it 'returns a StringIO with log output' do
      dir = create(:directory, path: @test_root, parent: nil)
      result = DirectoryReconciliationService.new(dir).call
      expect(result).to be_a(StringIO)
      expect(result.string).to include('Starting recreate')
    end

    it 'syncs database with filesystem directories' do
      root = create(:directory, path: @test_root, parent: nil)

      # Create directories on disk that don't exist in DB
      FileUtils.mkdir_p("#{@test_root}/newdir1")
      FileUtils.mkdir_p("#{@test_root}/newdir2")

      expect do
        DirectoryReconciliationService.new(root).call
      end.to change { Directory.count }.by_at_least(1)
    end

    it 'removes database records for directories not on disk' do
      root = create(:directory, path: @test_root, parent: nil)
      # Create orphan as a subdir in database only (not on disk)
      orphan = Directory.new(name: 'orphan', parent_id: root.id, hidden: false)
      orphan.path = "#{@test_root}/orphan"
      orphan.title = 'Orphan'
      # Skip callbacks that would try to create directory
      orphan.define_singleton_method(:make_path) {}
      orphan.save!(validate: false)

      # Reload root to ensure association is current
      root.reload
      expect(root.subdirs).to include(orphan)

      # Don't create the directory on disk

      expect do
        DirectoryReconciliationService.new(root).call
      end.to change { Directory.exists?(orphan.id) }.from(true).to(false)
    end
  end

  describe '#recreate' do
    it 'scans disk and creates missing directory records' do
      root = create(:directory, path: @test_root, parent: nil)
      FileUtils.mkdir_p("#{@test_root}/scanned")

      destroy_dirs = {}
      root.recreate(destroy_dirs)

      expect(Directory.find_by(name: 'scanned')).not_to be_nil
    end

    it 'marks subdirs not found on disk for deletion' do
      root = create(:directory, path: @test_root, parent: nil)
      # Create orphan as a subdir in database only (not on disk)
      orphan = Directory.new(name: 'orphan', parent_id: root.id, hidden: false)
      orphan.path = "#{@test_root}/orphan"
      orphan.title = 'Orphan'
      orphan.define_singleton_method(:make_path) {}
      orphan.save!(validate: false)
      root.reload

      destroy_dirs = {}
      result = root.recreate(destroy_dirs)

      expect(result).to have_key(orphan.id)
    end
  end

  describe '#find_existing' do
    it 'finds subdir by name when it exists' do
      parent = create(:directory, path: @test_root, parent: nil)
      existing = create(:directory, name: 'existing', parent: parent)

      result = parent.find_existing('existing', "#{@test_root}/existing")
      expect(result).to eq(existing)
    end

    it 'finds orphaned directory with matching name' do
      parent = create(:directory, path: @test_root, parent: nil)
      # Create orphan with path that doesn't exist - skip make_path callback
      orphan = Directory.new(name: 'orphan', path: '/tmp/nonexist/orphan', hidden: false)
      orphan.title = 'Orphan'
      orphan.define_singleton_method(:make_path) {} # Override callback
      orphan.save!(validate: false)

      result = parent.find_existing('orphan', "#{@test_root}/orphan")
      expect(result).to eq(orphan)
    end

    it 'returns nil when no match found' do
      parent = create(:directory, path: @test_root, parent: nil)
      result = parent.find_existing('notfound', "#{@test_root}/notfound")
      expect(result).to be_nil
    end
  end

  describe 'permission methods' do
    let(:directory) { build(:directory) }

    describe '#can_create?' do
      it 'returns false for nil user' do
        expect(directory.can_create?(nil)).to be false
      end

      it 'returns true for admin user' do
        admin = double('user', admin?: true)
        expect(directory.can_create?(admin)).to be true
      end

      it 'returns false for non-admin user' do
        user = double('user', admin?: false)
        expect(directory.can_create?(user)).to be false
      end
    end

    describe '#can_update?' do
      it 'returns false for nil user' do
        expect(directory.can_update?(nil)).to be false
      end

      it 'returns true for admin with valid params' do
        admin = double('user', admin?: true)
        expect(directory.can_update?(admin, { description: 'test', hidden: true })).to be true
      end

      it 'returns false for admin with invalid params' do
        admin = double('user', admin?: true)
        expect(directory.can_update?(admin, { name: 'test' })).to be false
      end

      it 'returns false for non-admin user' do
        user = double('user', admin?: false)
        expect(directory.can_update?(user, { description: 'test' })).to be false
      end
    end

    describe '#can_destroy?' do
      it 'returns false for nil user' do
        expect(directory.can_destroy?(nil)).to be false
      end

      it 'returns true for admin user' do
        admin = double('user', admin?: true)
        expect(directory.can_destroy?(admin)).to be true
      end

      it 'returns false for non-admin user' do
        user = double('user', admin?: false)
        expect(directory.can_destroy?(user)).to be false
      end
    end
  end

  describe '.params' do
    it 'permits expected attributes' do
      params = ActionController::Parameters.new(
        directory: {
          description: 'Test',
          hidden: true,
          name: 'testdir',
          parent_id: 1,
          unauthorized_param: 'not allowed'
        }
      )

      result = Directory.params(params, nil)
      expect(result.permitted?).to be true
      expect(result.keys).to match_array(%w[description hidden name parent_id])
    end
  end

  describe '.sync_download_root' do
    it 'adds year segment for logs downloads' do
      allow(described_class).to receive(:sync_download_base_root).with('logs').and_return('/tmp/files/logs')

      path = described_class.sync_download_root(kind: 'logs', nickname: 'Server 1', year: 2026)

      expect(path).to eq('/tmp/files/logs/server_1/2026')
    end

    it 'does not add year segment for non-log downloads' do
      allow(described_class).to receive(:sync_download_base_root).with('demos').and_return('/tmp/files/demos')

      path = described_class.sync_download_root(kind: 'demos', nickname: 'Server 1', year: 2026)

      expect(path).to eq('/tmp/files/demos/server_1')
    end

    it 'returns nil when nickname sanitizes to blank' do
      allow(described_class).to receive(:sync_download_base_root).with('demos').and_return('/tmp/files/demos')

      expect(described_class.sync_download_root(kind: 'demos', nickname: '   ')).to be_nil
    end
  end

  describe '.sanitize_sync_year_segment' do
    it 'returns a four-digit year as a string' do
      expect(described_class.sanitize_sync_year_segment(2026)).to eq('2026')
    end

    it 'returns nil for invalid year values' do
      expect(described_class.sanitize_sync_year_segment('26')).to be_nil
    end
  end

  describe '.sync_kind_for_filename' do
    it 'detects demo and log files case-insensitively' do
      expect(described_class.sync_kind_for_filename('MATCH.DEM.GZ')).to eq(Directory::SYNC_KIND_DEMOS)
      expect(described_class.sync_kind_for_filename('server.LOG')).to eq(Directory::SYNC_KIND_LOGS)
    end

    it 'returns nil for unsupported filenames' do
      expect(described_class.sync_kind_for_filename('notes.txt')).to be_nil
    end
  end

  describe '.sync_download_base_root' do
    it 'falls back to FILES_ROOT paths when directories are missing' do
      expect(described_class.sync_download_base_root('demos')).to eq(File.join(@test_root, 'demos'))
      expect(described_class.sync_download_base_root('logs')).to eq(File.join(@test_root, 'logs'))
    end
  end

  describe '#ignored_reconciliation_path?' do
    let(:directory) { create(:directory, :root, path: @test_root) }

    it 'returns true for ignored top-level folders' do
      expect(directory.ignored_reconciliation_path?(File.join(@test_root, 'uploads', 'file.txt'))).to be(true)
    end

    it 'returns false for blank and unrelated paths' do
      expect(directory.ignored_reconciliation_path?(nil)).to be(false)
      expect(directory.ignored_reconciliation_path?('/tmp/elsewhere/file.txt')).to be(false)
    end
  end

  describe '.find_by_inode_and_verify' do
    it 'returns the directory when inode matches and the path still exists' do
      dir = create(:directory, name: 'inodekeep')
      dir.sync_inode_info

      expect(described_class.find_by_inode_and_verify(dir.full_path, dir.st_dev, dir.st_ino)).to eq(dir)
    end

    it 'returns nil when the inode matches but the filesystem path is gone' do
      dir = create(:directory, name: 'inodegone')
      dir.sync_inode_info
      FileUtils.rm_rf(dir.full_path)

      expect(described_class.find_by_inode_and_verify(dir.full_path, dir.st_dev, dir.st_ino)).to be_nil
    end
  end
end
