require 'rails_helper'

RSpec.describe DirectoryReconciliationService, type: :service do
  before do
    DatabaseCleaner.start
    @test_root = '/tmp/test_deterministic_reconciliation'
    FileUtils.rm_rf(@test_root)
    FileUtils.mkdir_p(@test_root)
    ENV['FILES_ROOT'] = @test_root
  end

  let(:root_directory) do
    Directory.find_or_create_by(id: Directory::ROOT) do |dir|
      dir.name = 'root'
      dir.path = @test_root
      dir.title = 'Root'
      dir.hidden = false
    end
  end

  after do
    ENV.delete('FILES_ROOT')
    FileUtils.rm_rf(@test_root) if File.directory?(@test_root)
    DatabaseCleaner.clean
  end

  describe 'directory move detection with inode tracking' do
    it 'correctly handles directory with children moved to different parent' do
      # Create simple structure:
      # root/
      #   parenta/
      #     childdir/
      #       grandchild1/
      #       grandchild2/
      #   parentb/

      parent_a_path = File.join(@test_root, 'parenta')
      parent_b_path = File.join(@test_root, 'parentb')
      child_path = File.join(parent_a_path, 'childdir')
      grandchild1_path = File.join(child_path, 'grandchild1')
      grandchild2_path = File.join(child_path, 'grandchild2')

      FileUtils.mkdir_p([parent_a_path, parent_b_path, grandchild1_path, grandchild2_path])

      # Create DB records
      parent_a = root_directory.subdirs.create!(name: 'parenta', path: parent_a_path, title: 'Parent A')
      parent_a.sync_inode_info

      parent_b = root_directory.subdirs.create!(name: 'parentb', path: parent_b_path, title: 'Parent B')
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
      service = DirectoryReconciliationService.new(root_directory)
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
