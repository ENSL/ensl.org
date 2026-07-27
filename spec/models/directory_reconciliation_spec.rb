# frozen_string_literal: true

require 'rails_helper'

describe 'Directory reconciliation behavior' do
  before(:all) do
    @test_root = '/tmp/test_dir_reconciliation'
    FileUtils.mkdir_p(@test_root)
  end

  after(:all) do
    FileUtils.rm_rf(@test_root)
  end

  before do
    # This spec must override the process-level root for isolated reconciliation behavior.
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

  after do
    FileUtils.rm_rf(@test_root) if Dir.exist?(@test_root)
    FileUtils.mkdir_p(@test_root)
  end

  let(:root_directory) { @root }

  describe 'name_unchanged_on_update validation' do
    it 'prevents name changes through regular save' do
      dir_path = File.join(@test_root, 'test_dir')
      FileUtils.mkdir_p(dir_path)

      dir = root_directory.subdirs.create!(name: 'testdir', path: dir_path, title: 'Test')

      # Attempt to change name through normal update
      dir.name = 'newname'
      expect { dir.save! }.to raise_error(ActiveRecord::RecordInvalid, /Name cannot be changed/)
    end

    it 'allows name changes through save with validate: false' do
      dir_path = File.join(@test_root, 'test_dir')
      FileUtils.mkdir_p(dir_path)

      dir = root_directory.subdirs.create!(name: 'testdir', path: dir_path, title: 'Test')

      # Change name bypassing validation (for reconciliation)
      dir.name = 'newname'
      expect { dir.save!(validate: false) }.not_to raise_error
      expect(dir.reload.name).to eq('newname')
    end
  end

  describe 'parent changes with name changes' do
    it 'handles both parent and name change during reconciliation move' do
      # Create initial structure
      parent1_path = File.join(@test_root, 'parent1')
      parent2_path = File.join(@test_root, 'parent2')
      child_path = File.join(parent1_path, 'child')

      FileUtils.mkdir_p([parent2_path, child_path])

      # Create DB records
      parent1 = root_directory.subdirs.create!(name: 'parent1', path: parent1_path, title: 'Parent 1')
      parent1.sync_inode_info
      parent2 = root_directory.subdirs.create!(name: 'parent2', path: parent2_path, title: 'Parent 2')
      parent2.sync_inode_info
      child = parent1.subdirs.create!(name: 'child', path: child_path, title: 'Child')
      child.sync_inode_info

      # Simulate filesystem move + rename: child moved to parent2 and renamed
      new_child_path = File.join(parent2_path, 'renamed_child')
      FileUtils.mv(child_path, new_child_path)

      # Reconciliation: find by inode and update parent + name
      child_to_move = Directory.find_by_inode(child.st_dev, child.st_ino)
      expect(child_to_move).to eq(child)

      child_to_move.parent = parent2
      child_to_move.name = 'renamed_child'
      child_to_move.path = new_child_path

      # This should succeed with validate: false
      expect { child_to_move.save!(validate: false) }.not_to raise_error

      child.reload
      expect(child.parent_id).to eq(parent2.id)
      expect(child.name).to eq('renamed_child')
      expect(child.path).to eq(new_child_path)
    end
  end

  describe 'inode tracking for moved directories' do
    it 'preserves inode info across FileUtils.mv' do
      dir_path = File.join(@test_root, 'movable')
      new_path = File.join(@test_root, 'moved')
      FileUtils.mkdir_p(dir_path)

      dir = root_directory.subdirs.create!(name: 'movable', path: dir_path, title: 'Movable')
      dir.sync_inode_info

      original_dev = dir.st_dev
      original_ino = dir.st_ino

      # Move the directory
      FileUtils.mv(dir_path, new_path)

      # Inode should be preserved
      stat = File.stat(new_path)
      expect(stat.dev).to eq(original_dev)
      expect(stat.ino).to eq(original_ino)

      # Should find by inode even though path changed
      found = Directory.find_by_inode(original_dev, original_ino)
      expect(found).to eq(dir)
    end

    it 'finds orphaned directories by inode' do
      dir_path = File.join(@test_root, 'orphan')
      FileUtils.mkdir_p(dir_path)

      dir = root_directory.subdirs.create!(name: 'orphan', path: dir_path, title: 'Orphan')
      dir.sync_inode_info

      # Move directory on disk without updating DB
      new_path = File.join(@test_root, 'orphaned')
      FileUtils.mv(dir_path, new_path)

      # DB still shows old path but inode lookup works
      dir.reload
      expect(dir.path).to eq(dir_path) # DB not updated
      expect(File.exist?(dir.path)).to be false # Path no longer exists

      # Inode lookup still finds it
      found = Directory.find_by_inode(dir.st_dev, dir.st_ino)
      expect(found).to eq(dir)
    end
  end

  describe 'move_subdir_to_self behavior' do
    it 'updates parent when directory is moved' do
      parent1_path = File.join(@test_root, 'src_parent')
      parent2_path = File.join(@test_root, 'dst_parent')
      child_path = File.join(parent1_path, 'child')

      FileUtils.mkdir_p([parent2_path, child_path])

      parent1 = root_directory.subdirs.create!(name: 'srcparent', path: parent1_path, title: 'Src')
      parent1.sync_inode_info
      parent2 = root_directory.subdirs.create!(name: 'dstparent', path: parent2_path, title: 'Dst')
      parent2.sync_inode_info
      child = parent1.subdirs.create!(name: 'child', path: child_path, title: 'Child')
      child.sync_inode_info

      original_parent = parent1.id

      # Call move_subdir_to_self from parent2 (using send to access private method)
      parent2.send(:move_subdir_to_self, child, Rails.logger)

      child.reload
      expect(child.parent_id).to eq(parent2.id)
      expect(child.parent_id).not_to eq(original_parent)
    end

    it 'updates both parent and name in move_subdir_to_self' do
      parent1_path = File.join(@test_root, 'move_src')
      parent2_path = File.join(@test_root, 'move_dst')
      child_path = File.join(parent1_path, 'oldname')

      FileUtils.mkdir_p([parent2_path, child_path])

      parent1 = root_directory.subdirs.create!(name: 'movesrc', path: parent1_path, title: 'Src')
      parent1.sync_inode_info
      parent2 = root_directory.subdirs.create!(name: 'movedst', path: parent2_path, title: 'Dst')
      parent2.sync_inode_info
      child = parent1.subdirs.create!(name: 'oldname', path: child_path, title: 'Old')
      child.sync_inode_info

      # Update DB record before move (simulating reconciliation having already found the changes)
      child.name = 'newname'
      child.path = File.join(parent2_path, 'newname')

      # Use move_subdir_to_self from new parent (using send to access private method)
      parent2.send(:move_subdir_to_self, child, Rails.logger)

      child.reload
      expect(child.parent_id).to eq(parent2.id)
      expect(child.name).to eq('newname')
    end
  end
end
