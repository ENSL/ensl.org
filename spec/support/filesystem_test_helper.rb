# frozen_string_literal: true

# Helper for creating realistic test filesystem structures
# Used for integration tests of directory reconciliation and file syncing
module FilesystemTestHelper
  # Create a realistic directory structure with files
  # Options:
  #   - depth: number of directory levels (default: 2)
  #   - files_per_dir: number of files per directory (default: 3)
  #   - size_range: range of file sizes in bytes (default: 1KB..10MB)
  #   - name_pattern: prefix for generated names (default: 'test')
  def create_test_filesystem(root_path, depth: 2, files_per_dir: 3, size_range: (1024..10_485_760),
                             name_pattern: 'test')
    FileUtils.mkdir_p(root_path)
    directories = []
    files = []
    @dir_counter = 0

    # Create directory structure
    create_directory_tree(root_path, depth, name_pattern, directories)

    # Add files to each directory
    directories.each do |dir_path|
      files_per_dir.times do |i|
        filename = "#{name_pattern}file#{SecureRandom.hex(4)}#{i}.dat"
        file_path = File.join(dir_path, filename)
        size = rand(size_range)
        # Write binary data in binary mode
        File.open(file_path, 'wb') { |f| f.write(SecureRandom.random_bytes(size)) }
        # Make files old enough (>100 seconds) for reconciliation to import them
        past_time = 110.seconds.ago.to_time
        File.utime(past_time, past_time, file_path)
        files << file_path
      end
    end

    { directories: directories, files: files, root: root_path }
  end

  # Create a directory tree structure
  private

  def create_directory_tree(parent_path, remaining_depth, name_pattern, directories)
    return if remaining_depth <= 0

    # Create 2-4 subdirectories at each level with simple alphanumeric names
    rand(2..4).times do |_i|
      @dir_counter += 1
      dir_name = "#{name_pattern}dir#{@dir_counter}".downcase[0..19] # Ensure max 20 chars
      dir_path = File.join(parent_path, dir_name)
      FileUtils.mkdir_p(dir_path)
      directories << dir_path

      # Recursively create subdirectories
      create_directory_tree(dir_path, remaining_depth - 1, name_pattern, directories)
    end
  end

  # Sync created filesystem structure into the database
  # Returns hash of directory records keyed by path
  def sync_filesystem_to_db(filesystem_structure, parent_directory)
    directories = {}
    files = {}

    # Create directory records recursively
    sync_directories_recursive(filesystem_structure[:root], parent_directory, directories)

    # Create file records
    filesystem_structure[:files].each do |file_path|
      # Find which database directory contains this file
      file_dir = File.dirname(file_path)
      containing_dir = directories.values.find { |d| d.full_path == file_dir }
      next unless containing_dir

      filename = File.basename(file_path)
      size = File.size(file_path)
      md5 = Digest::MD5.hexdigest(File.read(file_path))

      # Insert directly using SQL to avoid CarrierWave and callback issues
      ActiveRecord::Base.connection.execute(
        'INSERT INTO data_files (directory_id, path, name, size, md5, title, created_at, updated_at) ' \
        "VALUES (#{containing_dir.id}, '#{file_path}', '#{filename}', #{size}, '#{md5}', '#{filename}', NOW(), NOW())"
      )
      # Re-query to get the created record
      db_file = DataFile.find_by(path: file_path)
      files[file_path] = db_file if db_file
    end

    { directories: directories, files: files }
  end

  def sync_directories_recursive(dir_path, parent_db_dir, directories_hash)
    Dir.glob(File.join(dir_path, '/*')).each do |item_path|
      next unless File.directory?(item_path)

      dir_name = File.basename(item_path).downcase
      db_dir = parent_db_dir.subdirs.build(
        name: dir_name,
        path: item_path,
        title: dir_name.titleize
      )
      db_dir.save!
      # Ensure inode info is captured for move detection
      db_dir.sync_inode_info
      directories_hash[item_path] = db_dir

      # Recursively sync subdirectories
      sync_directories_recursive(item_path, db_dir, directories_hash)
    end
  end

  private :sync_directories_recursive

  # Delete random files from the filesystem (simulating missing/deleted files)
  def delete_random_files(filesystem_structure, count)
    deleted = []
    deleted_count = 0

    filesystem_structure[:files].shuffle.each do |file_path|
      break if deleted_count >= count

      next unless File.exist?(file_path)

      File.delete(file_path)
      deleted << file_path
      deleted_count += 1
    end

    deleted
  end

  # Delete random directories from the filesystem (simulating removed directories)
  def delete_random_directories(filesystem_structure, count)
    deleted = []
    deleted_count = 0

    # Sort by depth (deepest first) to avoid errors when deleting parents before children
    dirs_by_depth = filesystem_structure[:directories].sort_by { |d| d.count('/') }.reverse

    dirs_by_depth.each do |dir_path|
      break if deleted_count >= count
      next unless File.directory?(dir_path)

      # Delete all files in this directory first
      Dir.glob(File.join(dir_path, '*')).each do |item|
        File.delete(item) if File.file?(item)
      end

      # Now delete the empty directory
      Dir.rmdir(dir_path)
      deleted << dir_path
      deleted_count += 1
    end

    deleted
  end

  # Add new files to existing directories (simulating file uploads)
  def add_random_files(filesystem_structure, count, size_range: (1024..10_485_760))
    added = []

    filesystem_structure[:directories].sample(count).each do |dir_path|
      filename = "#{SecureRandom.hex(8)}.dat"
      file_path = File.join(dir_path, filename)
      size = rand(size_range)
      File.open(file_path, 'wb') { |f| f.write(SecureRandom.random_bytes(size)) }
      # Make file old enough (>100 seconds ) for reconciliation to import it
      past_time = 110.seconds.ago.to_time
      File.utime(past_time, past_time, file_path)
      added << file_path
    end

    added
  end

  # Add new directories (simulating folder creation)
  def add_random_directories(filesystem_structure, count)
    added = []

    filesystem_structure[:directories].sample(count).each do |parent_dir|
      new_dir = File.join(parent_dir, "newdir_#{SecureRandom.hex(4)}")
      FileUtils.mkdir_p(new_dir)
      added << new_dir
    end

    added
  end
end

RSpec.configure do |config|
  config.include FilesystemTestHelper
end
