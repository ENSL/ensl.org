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

  has_many :related_files, class_name: 'DataFile', foreign_key: :related_id
  has_many :comments, as: :commentable
  has_one :movie, foreign_key: :file_id, dependent: :destroy
  has_one :preview, class_name: 'Movie', foreign_key: :preview_id, dependent: :nullify
  has_one :match, foreign_key: :demo_id
  belongs_to :directory, optional: true
  belongs_to :related, class_name: 'DataFile', optional: true
  belongs_to :article, optional: true

  validates_length_of %i[description path], maximum: 255

  # Callback chain for file processing (order matters)
  before_save :sync_file_metadata, if: -> { location.present? && File.exist?(location) }
  before_save :move_file_between_directories, if: -> { directory_id_changed? && !new_record? }
  before_save :ensure_path_cached, if: :directory
  before_validation :auto_generate_description, if: -> { description.blank? }
  before_save :auto_link_preview_file, if: -> { !related && location.present? && location.include?('_preview.mp4') }
  after_save :update_movie_metadata, if: -> { movie && saved_change_to_md5? }
  after_create :create_movie, if: :should_create_movie?
  after_save :update_relations, if: :should_update_relations?

  # acts_as_rateable
  mount_uploader :name, FileUploader

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

  # Shortcut to get the URL for this file from CarrierWave
  def url
    name.url
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

  # Recompute MD5, size, and timestamp from actual file on disk
  def sync_file_metadata
    return if location.blank? || !File.exist?(location)
    return unless new_record? || file_changed_on_disk?

    self.md5 = Digest::MD5.hexdigest(File.read(location))
    self.size = File.size(location)
    self.created_at = File.mtime(location)
  end

  # Check if the actual file has changed since last save
  def file_changed_on_disk?
    size != File.size(location) || created_at != File.mtime(location)
  end

  # Move file on disk when directory changes (uses old cached path and new location)
  def move_file_between_directories
    return unless path && File.exist?(path)
    return unless directory&.full_path # Guard: directory must exist
    return if location.blank? || path == location # Already in correct location or no target

    FileUtils.mv(path, location)
    Rails.logger.info("Moved file from #{path} to #{location}")
  rescue StandardError => e
    Rails.logger.error("Failed to move file from #{path} to #{location}: #{e.message}")
    errors.add(:base, "File system error: Cannot move file - #{e.message}")
    raise ActiveRecord::RecordInvalid, self
  end

  # Cache the full path in the path attribute for query performance
  def ensure_path_cached
    return unless directory

    new_path = File.join(directory.full_path, File.basename(name.to_s))
    self.path = new_path if path.nil? || directory_id_changed?
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
    movie.get_length
  end

  public

  def should_create_movie?
    directory_id == Directory::MOVIES && !location.include?('_preview.mp4')
  end

  def should_update_relations?
    # Check if related_id changed in the previous save and we have related files
    saved_change_to_related_id? && related_files.any?
  end

  def create_movie
    movie = Movie.new
    movie.file = self
    movie.make_snapshot 5
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

  # Find existing file record by path or checksum (disk-authoritative lookup)
  def self.find_existing(subitem_path, _subitem_name)
    return DataFile.find_by(path: subitem_path) if File.exist?(subitem_path)

    hash = compute_file_hash(subitem_path)
    return unless hash

    DataFile.find_by(md5: hash)
  rescue StandardError => e
    Rails.logger.error("Error finding existing file for #{subitem_path}: #{e.message}")
    nil
  end

  # Safely compute MD5 hash of a file
  def self.compute_file_hash(file_path)
    Digest::MD5.hexdigest(File.read(file_path))
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
