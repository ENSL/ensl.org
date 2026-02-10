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

# DataFile uses CarrierWave to manage files. The attrribute 'name' is the most crucial attribute.
# Avoid using .path for anything, rather use .location which is alias.

require 'digest/md5'

class DataFile < ActiveRecord::Base
  include Extra

  MEGABYTE = 1_048_576

  attr_accessor :related_id

  scope :recent, -> { order('created_at DESC').limit(8) }
  scope :demos, lambda {
    order('created_at DESC').where('directory_id IN (SELECT id FROM directories WHERE parent_id = ?)', Directory::DEMOS)
  }
  scope :ordered, -> { order('created_at DESC') }
  scope :movies, -> { order('created_at DESC').where({ directory_id: Directory::MOVIES }) }
  scope :not, ->(file) { where.not(id: file.id) }
  scope :unrelated, -> { where('related_id is null') }

  has_many :related_files, class_name: 'DataFile', foreign_key: :related_id
  has_many :comments, as: :commentable
  has_one :movie, foreign_key: :file_id, dependent: :destroy
  has_one :preview, class_name: 'Movie', foreign_key: :preview_id, dependent: :nullify
  has_one :match, foreign_key: :demo_id
  belongs_to :directory, optional: true
  belongs_to :related, class_name: 'DataFile', optional: true
  belongs_to :article, optional: true

  validates_length_of %i[description path], maximum: 255

  before_save :process_file
  after_create :create_movie, if: proc { |file| file.directory_id == Directory::MOVIES and !file.location.include?('_preview.mp4') }
  after_save :update_relations, if: proc { |file| file.related_id_changed? and related_files.count.positive? }

  # acts_as_rateable
  mount_uploader :name, FileUploader

  def to_s
    description && description.empty? ? File.basename(name.to_s) : description
  end

  def md5_s
    md5.upcase
  end

  def extra_url
    url.to_s.gsub(%r{^/files}, 'http://extra.ensl.org/static')
  end

  def size_s
    "#{(size.to_f / MEGABYTE).round(2)} MB"
  end

  # Just an alias, use this to find the file's current path
  def location
    name.current_path
  end

  def url
    name.url
  end

  def manual_upload(manual_location)
    File.open(manual_location) do |f|
      self.name = f
    end
  end

  def process_file
    self.md5 = 'e948c22100d29623a1df48e1760494df'

    self.directory_id = Directory::ARTICLES if article

    if File.exist?(location) && (new_record? || (size != File.size(location)) || (created_at != File.mtime(location)))
      self.md5 = Digest::MD5.hexdigest(File.read(location))
      self.size = File.size(location)
      self.created_at = File.mtime(location)
    end

    # Update the path on creation

    # Move the file if it has moved
    FileUtils.mv(path, location) if !new_record? && directory_id_changed? && File.exist?(path)

    self.path = File.join(directory.full_path, File.basename(name.to_s)) if path.nil? || directory_id_changed?

    if description.nil? || description.empty?
      self.description = File.basename(location).gsub(/[_-]/, ' ').gsub(/\.\w{1,5}$/, '')
      self.description = description.split(/\s+/).each(&:capitalize!).join(' ')
    end

    self.description = "#{match.contester1} vs #{match.contester2}" if match

    if location.include?('_preview.mp4') && !related
      stripped = location.gsub(/_preview\.mp4/, '')
      DataFile.where(['path LIKE ?', "#{stripped}%"]).each do |r|
        self.related = r if r.location.match(/#{stripped}\.\w{1,5}$/)
      end
    end

    return unless movie && (new_record? || md5_changed?)

    movie.get_length
  end

  def create_movie
    movie = Movie.new
    movie.file = self
    movie.make_snapshot 5
    movie.save
  end

  def update_relations
    related_files.each do |rf|
      rf.related = related
      rf.save
    end
  end

  def rateable?(user)
    user and !rated_by?(user)
  end

  # TODO: instead of using path, use name + directory path
  def self.find_existing(subitem_path, _subitem_name)
    hash = Digest::MD5.hexdigest(File.read(subitem_path))
    DataFile.where(arel_table[:path].eq(subitem_path)\
      .or(arel_table[:md5].eq(hash))).first
  end

  def can_create?(cuser)
    return false unless cuser
    return false if cuser.banned?(Ban::TYPE_MUTE)

    (cuser.admin? or \
     (article&.can_create? cuser) or \
     (directory_id == Directory::MOVIES and cuser.has_access? Group::MOVIES))
  end

  def can_update?(cuser)
    cuser&.admin? or (article&.can_create? cuser)
  end

  def can_destroy?(cuser)
    cuser&.admin? or (article&.can_create? cuser)
  end

  def self.params(params, _cuser)
    params.require(:data_file).permit(:description, :name, :article_id, :related_id, :directory_id)
  end
end
