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
#  st_dev      :bigint           Filesystem device ID for inode tracking
#  st_ino      :bigint           Inode number for filesystem-independent identification
#  created_at  :datetime
#  updated_at  :datetime
#  parent_id   :integer
#
# Indexes
#
#  index_directories_on_parent_id  (parent_id)
#  index_directories_on_inode      (st_dev, st_ino) UNIQUE
#
require 'securerandom'
require 'stringio'
require 'fileutils'
require 'pathname'

ENV['FILES_ROOT'] ||= File.join(Rails.root, 'public', 'files')

class Directory < ActiveRecord::Base
  include Extra

  IGNORED_RECONCILIATION_ROOT_DIRS = %w[uploads .trash].freeze

  ROOT = 1
  DEMOS = 5
  DEMOS_DEFAULT = 19
  DEMOS_GATHERS = 92
  MOVIES = 30
  ARTICLES = 39

  attr_accessor :preserve_files, :move_to_trash

  belongs_to :parent, class_name: 'Directory', optional: true
  has_many :subdirs, class_name: 'Directory', foreign_key: :parent_id
  has_many :files, -> { order('name') }, class_name: 'DataFile'

  scope :ordered, ->  { order('name ASC') }
  scope :path_sorted, -> { order('path ASC') }
  scope :filtered, -> { where(hidden: false) }
  scope :of_parent, ->(parent) { where(parent_id: parent.id) }

  validates :name, presence: true, length: { in: 1..255 }, format: { with: /\A[A-Za-z0-9]{1,20}\z/, on: :create }
  validates :path, presence: true, length: { in: 1..255 }
  validate :name_unchanged_on_update, on: :update
  validates :title, presence: true, length: { in: 1..255 }
  validates :hidden, inclusion: { in: [true, false] }

  before_validation :ensure_path_cached
  before_validation :set_default_title, on: :create
  before_validation :set_default_hidden, on: :create
  after_create :make_path
  after_create :sync_inode_info
  after_save :update_timestamp
  before_destroy :remove_files, unless: :preserve_files?
  after_destroy :remove_path, unless: :skip_remove_path?

  def to_s
    name
  end

  def parent_root?
    parent&.id == Directory::ROOT
  end

  def root?
    id == Directory::ROOT
  end

  def preserve_files?
    preserve_files == true
  end

  def move_to_trash?
    move_to_trash == true
  end

  private

  # Prevent renaming directories after creation (would break filesystem structure)
  def name_unchanged_on_update
    return unless name_changed?

    errors.add(:name, 'cannot be changed after creation')
  end

  public

  def full_title
    Directory.directory_traverse(self).reverse.map do |dir|
      dir.title.present? ? dir.title : dir.name
    end.join(' » ')
  end

  # Recursively traverse up the directory hierarchy to build
  # a list of ancestors (including self)
  def self.directory_traverse(directory, list = [])
    return list if directory.nil? || directory.root?

    list << directory
    directory_traverse(directory.parent, list)
  end

  # Get the full filesystem path for this directory (used for file storage)
  def full_path
    if parent
      File.join(parent.full_path, name.to_s.downcase)
    elsif root?
      # Root directory always uses ENV, not stored path
      ENV['FILES_ROOT']
    elsif path.present?
      path
    else
      File.join(ENV['FILES_ROOT'], name.to_s.downcase)
    end
  end

  # Returns the path relative to FILES_ROOT (used for CarrierWave storage)
  def relative_path
    return '' if root?
    return name.to_s.downcase if parent.nil?

    File.join(parent.relative_path, name.to_s.downcase).sub(%r{^/}, '')
  end

  def path_exists?
    File.directory?(full_path)
  end

  # Cache the full hierarchical path for non-root directories
  def ensure_path_cached
    if parent
      self.path = full_path
    elsif root?
      # Root directory path is managed via ENV['FILES_ROOT']
      self.path = ENV['FILES_ROOT']
    elsif path.blank?
      self.path = File.join(ENV['FILES_ROOT'], name.to_s.downcase)
    end
  end

  # Auto-generate title from directory name if not provided
  # Only runs once during initial creation
  def set_default_title
    return if @title_default_applied # Already ran once

    @title_default_applied = true

    return if title.present?
    return unless path.present? && new_record?

    self.title = File.basename(path).capitalize
  end

  # Default hidden to false
  def set_default_hidden
    self.hidden = false if hidden.nil?
  end

  def make_path
    return if File.exist?(full_path)

    FileUtils.mkdir_p(full_path)
    Rails.logger.info("Created directory: #{full_path}")
  rescue StandardError => e
    Rails.logger.error("Failed to create directory #{full_path}: #{e.message}")
    errors.add(:base, "Filesystem error: Cannot create directory - #{e.message}")
    raise ActiveRecord::RecordInvalid.new(self)
  end

  def update_timestamp
    return unless File.exist?(full_path)

    update_column(:created_at, File.mtime(full_path))
  rescue StandardError => e
    Rails.logger.warn("Failed to update timestamp for #{full_path}: #{e.message}")
  end

  # Capture filesystem inode information for location-independent directory identification
  def sync_inode_info
    return unless File.exist?(full_path)

    stat = File.stat(full_path)
    self.st_dev = stat.dev
    self.st_ino = stat.ino
    save!(validate: false) if changed?
  rescue StandardError => e
    Rails.logger.warn("Could not capture inode info for #{full_path}: #{e.message}")
  end

  def remove_files
    move_directory_to_trash if move_to_trash?
    files.destroy_all
    subdirs.each do |subdir|
      subdir.preserve_files = preserve_files? || move_to_trash?
      subdir.destroy
    end
  end

  def remove_path
    return unless File.exist?(full_path)
    return unless Dir.empty?(full_path)

    Dir.unlink(full_path)
  rescue StandardError => e
    Rails.logger.error("Failed to remove directory #{full_path}: #{e.message}")
  end

  def skip_remove_path?
    preserve_files? || move_to_trash?
  end

  def move_directory_to_trash
    return unless Dir.exist?(full_path)

    ensure_trash_root
    trash_path = next_trash_path
    FileUtils.mv(full_path, trash_path)
    Rails.logger.info("Moved directory to trash: #{full_path} -> #{trash_path}")
  rescue StandardError => e
    Rails.logger.error("Failed to move directory #{full_path} to trash: #{e.message}")
    errors.add(:base, "Filesystem error: Cannot move to trash - #{e.message}")
    raise ActiveRecord::RecordInvalid.new(self)
  end

  def ensure_trash_root
    FileUtils.mkdir_p(trash_root)
  end

  def trash_root
    File.join(ENV['FILES_ROOT'], '.trash')
  end

  def next_trash_path
    base = File.basename(full_path)
    timestamp = Time.now.utc.strftime('%Y%m%d%H%M%S')
    candidate = File.join(trash_root, "#{base}_#{id}_#{timestamp}")
    return candidate unless File.exist?(candidate)

    unique_suffix = SecureRandom.hex(4)
    File.join(trash_root, "#{base}_#{id}_#{timestamp}_#{unique_suffix}")
  end

  # Recursively sync this directory's database state with filesystem
  # Disk is authoritative - we scan actual directories and match to DB records
  def recreate(destroy_dirs, logger: Rails.logger)
    # Mark all existing subdirs for deletion (we'll unmark those found on disk)
    destroy_dirs.merge!(subdirs.reject { |subdir| ignored_reconciliation_directory?(subdir) }.index_by(&:id))

    scan_disk_entries(destroy_dirs, logger)
    destroy_dirs
  end

  private

  # Scan all items in this directory on disk and sync with database
  def scan_disk_entries(destroy_dirs, logger)
    Dir.glob(File.join(full_path, '*')).each do |item_path|
      if ignored_reconciliation_path?(item_path)
        logger.info("Skipping ignored path: #{item_path}")
        next
      end

      item_name = File.basename(item_path)

      begin
        if File.directory?(item_path)
          process_disk_directory(item_name, item_path, destroy_dirs, logger)
        elsif File.file?(item_path)
          process_disk_file(item_path, item_name, logger)
        end
      rescue StandardError => e
        logger.error("Error processing #{item_path}: #{e.message}")
      end
    end
  rescue StandardError => e
    logger.error("Error scanning #{full_path}: #{e.message}")
  end

  # Process a directory found on disk
  def process_disk_directory(item_name, item_path, destroy_dirs, logger)
    subdir = find_or_create_subdir(item_name, item_path, logger)
    return unless subdir

    # If parent changed, move the record (this also saves)
    if subdir.parent_id != id
      # Update name if it changed BEFORE moving (so move can use correct name)
      subdir.name = item_name.downcase if subdir.name != item_name.downcase

      move_subdir_to_self(subdir, logger)
    elsif !subdir.valid?
      fix_subdir_attributes(subdir, logger)
    elsif subdir.name != item_name.downcase
      # Reconciliation is disk-authoritative: persist in-place rename without strict validations
      old_path = subdir.full_path
      subdir.name = item_name.downcase
      subdir.path = subdir.full_path
      subdir.save!(validate: false)
      subdir.sync_inode_info
      logger.info("Renamed dir: #{old_path} -> #{subdir.full_path}")
    end

    destroy_dirs.delete(subdir.id)
    subdir.recreate(destroy_dirs, logger: logger)
  end

  # Find existing directory or create new one
  def find_or_create_subdir(item_name, item_path, logger)
    if (subdir = find_existing(item_name, item_path))
      subdir
    else
      create_new_subdir(item_name, logger)
    end
  end

  # Create a new directory record for discovered disk directory
  def create_new_subdir(item_name, logger)
    subdir = subdirs.build(name: item_name)
    subdir.save!(validate: false) # Skip validation for disk-found dirs
    logger.info("New dir: #{subdir.full_path}")
    subdir
  rescue StandardError => e
    logger.error("Failed to create subdir #{item_name}: #{e.message}")
    nil
  end

  # Move a directory record to this parent
  def move_subdir_to_self(subdir, logger)
    old_path = subdir.full_path
    subdir.parent = self
    subdir.path = subdir.full_path # Update path to match new location
    subdir.save!(validate: false) # Skip validations - disk is authoritative for reconciliation
    subdir.sync_inode_info # Ensure inode info is synced after move
    logger.info("Renamed dir: #{old_path} -> #{subdir.full_path}")
  rescue StandardError => e
    logger.error("Failed to move subdir: #{e.message}")
  end

  # Fix invalid directory attributes
  def fix_subdir_attributes(subdir, logger)
    subdir.errors.full_messages.each { |err| logger.warn(err) }
    # Manually re-initialize attributes that may be missing
    subdir.path = subdir.full_path if subdir.path.blank?
    subdir.title = subdir.name.capitalize if subdir.title.blank?
    subdir.hidden = false if subdir.hidden.nil?
    subdir.save!
    subdir.sync_inode_info # Ensure inode info is synced after fix
    logger.info("Fixed attributes: #{subdir.full_path}")
  rescue StandardError => e
    logger.error("Failed to fix subdir attributes: #{e.message}")
  end

  # Process a file found on disk
  def process_disk_file(item_path, item_name, logger)
    if (dbfile = DataFile.find_existing(item_path, item_name))
      update_file_directory(dbfile, logger)
    elsif file_is_old_enough?(item_path)
      create_new_file(item_path, logger)
    end
  end

  # Update file's directory if it moved
  def update_file_directory(dbfile, logger)
    return if dbfile.directory_id == id

    dbfile.update!(directory: self)
    logger.info("Update file: #{dbfile.name}")
  rescue StandardError => e
    logger.error("Failed to update file #{dbfile.name}: #{e.message}")
  end

  # Only import files older than 100 seconds (avoid in-progress uploads)
  def file_is_old_enough?(file_path)
    (File.mtime(file_path) + 100).past?
  end

  # Create new file record from disk file
  def create_new_file(item_path, logger)
    dbfile = DataFile.new(directory: self)
    dbfile.manual_upload(item_path)
    dbfile.save!
    logger.info("Added file: #{dbfile.name}")
  rescue StandardError => e
    logger.error("Failed to create file from #{item_path}: #{e.message}")
  end

  public

  # Find existing directory record matching disk directory
  # Uses inode priority: st_dev + st_ino first, then name match, orphaned record, file count match
  def find_existing(subdir_name, subitem_path)
    # First: try to match by inode (fastest, filesystem-independent)
    if File.directory?(subitem_path)
      stat = File.stat(subitem_path)
      inode_match = Directory.find_by_inode(stat.dev, stat.ino)
      return inode_match if inode_match
    end

    # Second: try direct name match under this parent
    return subdirs.find_by(name: subdir_name) if subdirs.exists?(name: subdir_name)

    # Third: find orphaned directory with same name (path doesn't exist anymore)
    orphaned = find_orphaned_directory(subdir_name)
    return orphaned if orphaned

    # Fourth: match by file count (heuristic for moved directories)
    find_by_file_count(subitem_path)
  end

  # Find directory with same name that no longer exists on disk
  def find_orphaned_directory(subdir_name)
    Directory.where(name: subdir_name).find { |dir| !dir.path_exists? }
  end

  def ignored_reconciliation_directory?(subdir)
    ignored_reconciliation_path?(subdir&.full_path)
  end

  def ignored_reconciliation_path?(absolute_path)
    return false if absolute_path.blank?

    root = Pathname.new(ENV['FILES_ROOT'].to_s)
    path = Pathname.new(absolute_path.to_s)
    relative_path = path.relative_path_from(root).to_s
    return false if relative_path.blank? || relative_path == '.'

    root_segment = relative_path.split(File::SEPARATOR).first
    IGNORED_RECONCILIATION_ROOT_DIRS.include?(root_segment)
  rescue ArgumentError
    false
  end

  # Attempt to find directory by matching file count (heuristic)
  def find_by_file_count(subitem_path)
    file_count = count_files_in_path(subitem_path)
    return nil if file_count.zero?

    candidate_dirs = Directory.joins(:files)
                              .group('directories.id')
                              .having('count(data_files.id) = ?', file_count)

    candidate_dirs.find { |dir| file_sizes_match?(dir, subitem_path) }
  rescue StandardError => e
    Rails.logger.warn("Error in find_by_file_count: #{e.message}")
    nil
  end

  # Count files in a directory path
  def count_files_in_path(path)
    Dir[File.join(path, '*')].count { |f| File.file?(f) }
  end

  # Check if all file sizes match between disk and database
  def file_sizes_match?(dir, disk_path)
    Dir.glob(File.join(disk_path, '*')).all? do |file_path|
      next true unless File.file?(file_path)

      filename = File.basename(file_path)
      db_file = dir.files.find_by(name: filename)
      db_file && File.size(file_path) == db_file.size
    end
  end

  # Find directory record by filesystem inode (st_dev + st_ino)
  # Returns nil if st_dev or st_ino is missing
  def self.find_by_inode(st_dev, st_ino)
    return nil unless st_dev && st_ino

    find_by(st_dev: st_dev, st_ino: st_ino)
  end

  # Find directory by inode and verify it still exists on filesystem
  # Returns directory if found and filesystem path exists
  # Returns nil if inode not found or filesystem path missing
  def self.find_by_inode_and_verify(dir_path, st_dev, st_ino)
    dir = find_by_inode(st_dev, st_ino)
    return nil unless dir
    return nil unless dir.path_exists?

    dir
  rescue StandardError => e
    Rails.logger.error("Error verifying directory by inode: #{e.message}")
    nil
  end

  # TODO: check that you can download files

  def can_create?(cuser)
    return false unless cuser

    cuser.admin?
  end

  def can_update?(cuser, params = {})
    return false unless cuser

    cuser.admin? && Verification.contain(params, %i[description hidden])
  end

  def can_destroy?(cuser)
    return false unless cuser

    cuser.admin?
  end

  def self.params(params, _cuser)
    params.require(:directory).permit(:description, :hidden, :name, :title, :parent_id)
  end
end
