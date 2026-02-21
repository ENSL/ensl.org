# frozen_string_literal: true

# == Schema Information
#
# Table name: data_files
#
#  id           :integer          not null, primary key
#  description  :string(255)
#  md5          :string(255)
#  name         :string(255)
#  path         :string(255)
#  size         :integer          not null
#  created_at   :datetime
#  updated_at   :datetime
#  article_id   :integer
#  directory_id :integer
#  related_id   :integer
#
# Indexes
#
#  index_data_files_on_article_id    (article_id)
#  index_data_files_on_directory_id  (directory_id)
#  index_data_files_on_related_id    (related_id)
#

# DataFile manages file uploads through CarrierWave mounted on the 'name' attribute.
#
# IMPORTANT - Path vs Location:
# - location (method): Returns current filesystem path via CarrierWave (name.current_path)
#   THIS IS THE SOURCE OF TRUTH - always use for file operations
# - path (column): Cached full path for query performance and tracking moves
#   Updated automatically when directory changes
#
# The filesystem is authoritative - metadata (MD5, size) is synced from actual files on disk.

require 'digest/md5'

class DataFile < ActiveRecord::Base
  include Extra

  MEGABYTE = 1_048_576

  scope :recent, -> { order('created_at DESC').limit(8) }
  scope :demos, lambda {
    joins(directory: :parent).where(directories: { parent_id: Directory::DEMOS }).order('data_files.created_at DESC')
  }
  scope :ordered, -> { order('created_at DESC') }
  scope :movies, -> { order('created_at DESC').where(directory_id: Directory::MOVIES) }
  scope :except_file, ->(file) { where.not(id: file.id) }
  scope :unrelated, -> { where(related_id: nil) }
  scope :orphaned, -> { where(directory_id: nil) }

  has_many :related_files, class_name: 'DataFile', foreign_key: :related_id
  has_many :comments, as: :commentable
  has_one :movie, foreign_key: :file_id, dependent: :destroy
  has_one :preview, class_name: 'Movie', foreign_key: :preview_id, dependent: :nullify
  has_one :match, foreign_key: :demo_id
  belongs_to :directory, optional: true
  belongs_to :related, class_name: 'DataFile', optional: true
  belongs_to :article, optional: true

  validates_length_of %i[description path], maximum: 255
  validates :name, presence: { message: 'Please select a file to upload' }, unless: :skip_file_validation_or_update?

  attr_accessor :skip_file_validation

  def skip_file_validation_or_update?
    skip_file_validation || !new_record?
  end

  # Callback chain for file processing (order matters)
  before_save :sync_file_metadata, if: -> { location.present? && File.exist?(location) }
  before_save :move_file_between_directories, if: -> { directory_id_changed? && !new_record? }
  before_validation :auto_generate_description, if: -> { description.blank? }
  before_save :auto_link_preview_file, if: -> { !related && location.present? && location.include?('_preview.mp4') }
  # after_save :update_movie_metadata, if: -> { !new_record? && movie && saved_change_to_md5? }
  after_create :create_movie, if: :should_create_movie?
  after_save :update_relations, if: :should_update_relations?

  # acts_as_rateable
  mount_uploader :name, FileUploader

  # Cache the final stored path after CarrierWave has stored/moved the file.
  # Declared after `mount_uploader` so it runs after CarrierWave's after_save.
  after_save :cache_path_from_uploader, if: -> { location.present? && File.exist?(location) }

  def to_s
    description.present? ? description : File.basename(path.to_s)
  end

  def md5_s
    md5.upcase
  end

  # Not used.
  def extra_url
    url.to_s.gsub(%r{^/files}, 'http://extra.ensl.org/static')
  end

  def size_s
    "#{(size.to_f / MEGABYTE).round(2)} MB"
  end

  # Shortcut to get the current file path from CarrierWave (source of truth)
  def location
    name.current_path
  end

  # Backward-compatible alias used by legacy callers.
  def full_path
    location.presence || path
  end

  def file_exists?
    File.exist?(location)
  end

  # Shortcut to get the URL for this file from CarrierWave
  # Prepends /files/ since nginx serves files directly from FILES_ROOT
  # This is needed because CarrierWave's url may not include the /files/
  # prefix because of custom root.
  # Do not call the CarrierWave url method directly in views
  def url
    carrywave_url = name.url
    return nil unless carrywave_url.present?

    # Ensure URL starts with /files/
    carrywave_url.start_with?('/files/') ? carrywave_url : "/files#{carrywave_url}"
  end

  # Get the top-level directory (root of the hierarchy) for this file
  def first_directory
    return nil unless directory

    dir = directory
    dir = dir.parent while dir.parent
    dir
  end

  # Get the second-level directory (immediate child of root) for this file, if it exists
  def second_directory
    return nil unless directory

    dir = directory
    dir = dir.parent while dir.parent
    dir == directory ? nil : directory
  end

  def manual_upload(manual_location)
    File.open(manual_location) do |f|
      self.name = f
    end
  end

  private

  # Absolute destination path based on CarrierWave storage rules.
  # This reflects the current model state (e.g. directory).
  def carrierwave_store_absolute_path
    identifier = name&.identifier
    return nil if identifier.blank?

    File.join(name.root.to_s, name.store_path(identifier).to_s)
  end

  # Recompute MD5, size, and timestamp from actual file on disk
  def sync_file_metadata
    return if location.blank? || !File.exist?(location)
    return unless new_record? || file_changed_on_disk?

    self.md5 = Digest::MD5.file(location).hexdigest
    self.size = File.size(location)
    self.created_at = File.mtime(location)
  end

  def file_changed_on_disk?
    disk_size = File.size(location)
    disk_mtime = File.mtime(location)

    size != disk_size || created_at.to_i != disk_mtime.to_i
  end

  # Move file on disk when directory changes (uses old cached path and new location)
  def move_file_between_directories
    old_path = path.presence || location
    return if old_path.blank? || !File.exist?(old_path)
    return unless directory&.full_path # Guard: directory must exist

    new_path = carrierwave_store_absolute_path
    return if new_path.blank? || old_path == new_path

    FileUtils.mkdir_p(File.dirname(new_path))
    FileUtils.mv(old_path, new_path)
    self.path = new_path

    # Refresh uploader state to reflect the moved file.
    name.retrieve_from_store!(name.identifier) if name&.identifier.present?

    Rails.logger.info("Moved file from #{old_path} to #{new_path}")
  rescue StandardError => e
    Rails.logger.error("Failed to move file from #{old_path} to #{new_path}: #{e.message}")
    errors.add(:base, "File system error: Cannot move file - #{e.message}")
    raise ActiveRecord::RecordInvalid, self
  end

  # Cache the final stored path in the DB for query performance.
  # Runs after CarrierWave has stored the file so we don't cache a tmp/cache path.
  def cache_path_from_uploader
    current_path = location
    return if current_path.blank? || !File.exist?(current_path)
    return if path == current_path

    update_column(:path, current_path)
  end

  # Auto-generate description from filename or match data
  def auto_generate_description
    self.description = if match
                         "#{match.contester1} vs #{match.contester2}"
                       else
                         generate_description_from_filename
                       end
  end

  # Clean up filename to create a readable description
  def generate_description_from_filename
    return 'Untitled' if location.blank?

    filename = File.basename(location)
    # Remove file extension and replace underscores/dashes with spaces
    cleaned = filename.gsub(/\.\w+$/, '').gsub(/[_-]/, ' ')
    # Capitalize each word
    cleaned.split(/\s+/).map(&:capitalize).join(' ')
  end

  # Link preview videos to their full versions
  def auto_link_preview_file
    basename = location.gsub(/_preview\.mp4$/, '')
    find_and_link_related_file(basename)
  end

  # Find the full-version file matching this preview
  def find_and_link_related_file(basename)
    DataFile.where('path LIKE ?', "#{basename}%").each do |candidate|
      if candidate.location.match?(/#{Regexp.escape(basename)}\.\w+$/)
        self.related = candidate
        return
      end
    end
  end

  # Update movie metadata if movie exists and file changed
  def update_movie_metadata
    movie.probe_metadata
  end

  public

  def should_create_movie?
    directory_id == Directory::MOVIES && !location.to_s.include?('_preview.mp4') && movie.nil?
  end

  def should_update_relations?
    # Check if related_id changed in the previous save and we have related files
    saved_change_to_related_id? && related_files.any?
  end

  def create_movie
    movie = Movie.new
    movie.file = self
    movie.save
  end

  def update_relations
    related_files.each do |rf|
      rf.update(related: related)
    end
  end

  def rateable?(user)
    user && !rated_by?(user)
  end

  # Class methods

  # Find existing file record by path, then checksum (disk-authoritative lookup)
  def self.find_existing(subitem_path, _subitem_name)
    return nil unless File.exist?(subitem_path)

    # Fall back to path-based lookup
    file = DataFile.find_by(path: subitem_path)
    return file if file

    # Fall back to checksum lookup
    hash = compute_file_hash(subitem_path)
    return unless hash

    DataFile.find_by(md5: hash)
  rescue StandardError => e
    Rails.logger.error("Error finding existing file for #{subitem_path}: #{e.message}")
    nil
  end

  # Safely compute MD5 hash of a file
  def self.compute_file_hash(file_path)
    Digest::MD5.file(file_path).hexdigest
  rescue StandardError => e
    Rails.logger.warn("Could not compute hash for #{file_path}: #{e.message}")
    nil
  end

  # Permission checks

  def can_create?(cuser)
    return false unless cuser
    return false if cuser.banned?(Ban::TYPE_MUTE)

    cuser.admin? || article&.can_create?(cuser) || (directory_id == Directory::MOVIES && cuser.has_access?(Group::MOVIES))
  end

  def can_update?(cuser)
    return false unless cuser

    cuser.admin? || article&.can_create?(cuser)
  end

  def can_destroy?(cuser)
    return false unless cuser

    cuser.admin? || article&.can_create?(cuser)
  end

  def self.params(params, _cuser)
    params.require(:data_file).permit(:description, :name, :article_id, :related_id, :directory_id)
  end
end
