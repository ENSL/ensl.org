
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

ENV['FILES_ROOT'] ||= File.join(Rails.root, 'public', 'files')

# class SteamIdValidator < ActiveModel::Validator
#   def validate(record)
#     record.errors.add :steamid unless \
#       record.steamid.nil? ||
#         (m = record.steamid.match(/\A([01]):([01]):(\d{1,10})\Z/)) &&
#         (id = m[3].to_i) &&
#         id >= 1 && id <= 2147483647
#   end
# end


class Directory < ActiveRecord::Base
  include Extra

  ROOT = 1
  DEMOS = 5
  DEMOS_DEFAULT = 19
  DEMOS_GATHERS = 92
  MOVIES = 30
  ARTICLES = 39

  #attr_protected :id, :updated_at, :created_at, :path

  belongs_to :parent, :class_name => "Directory", :optional => true
  has_many :subdirs, :class_name => "Directory", :foreign_key => :parent_id
  has_many :files, -> { order("name") }, :class_name => "DataFile"

  scope :ordered, ->  { order("name ASC") }
  scope :filtered, -> { where(hidden: false) }
  scope :of_parent, -> (parent) { where(parent_id: parent.id) }

  validates_length_of [:name, :path], :in => 1..255
  validates_format_of :name, :with => /\A[A-Za-z0-9]{1,20}\z/, :on => :create
  validates_length_of :name, :in => 1..25
  validates_inclusion_of :hidden, :in => [true, false]
  # TODO: add validation for path

  before_validation :init_variables
  after_create :make_path
  after_save :update_timestamp
  before_destroy :remove_files
  after_destroy :remove_path

  def to_s
    name
  end

  def init_variables
    self.path = full_path if parent
    self.hidden = false if hidden.nil?
  end

  def path_exists?
    File.directory?(full_path)
  end

  def full_path
    parent ? File.join(parent.full_path, name.downcase) : path
  end

  def make_path
    Dir.mkdir(full_path) unless File.exists?(full_path)
  end 

  def update_timestamp
    self.created_at = File.mtime(full_path) if File.exists?(full_path)
  end
  
  def remove_files
    files.each do |subdir|
      subdir.destroy
    end
    subdirs.each do |subdir|
      subdir.destroy
    end
  end

  def remove_path
    Dir.unlink(full_path) if File.exists?(full_path)
  end

  # TODO: make tests for this, moving etc.
  # TODO: mutate instead of return.
  def recreate_transaction(root = ENV['FILES_ROOT'])
    logger = Rails.logger
    logger.info 'Starting recreate on %d, root: %s' % [id, root]
    ActiveRecord::Base.transaction do
      # We use destroy lists so technically there can be seperate roots
      destroy_dirs = Hash.new
      update_attribute :path, root
      destroy_dirs = recreate(destroy_dirs)
      destroy_dirs.each do |key, dir|
        logger.info 'Removed dir: %s' % dir.full_path
        # dir.destroy!
      end
    end
    logger.info 'Finish recreate'
    return nil
    # TODO: check items that weren't checked.
  end

  # QUESTION Symlinks?
  def recreate(destroy_dirs, path = self.full_path)
    # Convert all subdirs into a hash and mark them to be deleted
    # FIXME: better oneliner
    destroy_dirs.merge!(subdirs.all.map{ |s| [s.id,s] }.to_h)

    # Go through all subdirectories (no recursion)
    Dir.glob("%s/*" % path).each do |subitem_path|
      if File.directory? subitem_path
        subdir_name = File.basename(subitem_path)

        # We find by name only, ignore path
        # Find existing subdirs from current path. Keep those we find
        if (subdir = find_existing(subdir_name, subitem_path))
          if subdir.parent_id != self.id
            old_path = subdir.full_path
            subdir.parent = self
            subdir.save!
            logger.info 'Renamed dir: %s -> %s' % [old_path, subdir.full_path]
          end
          destroy_dirs.delete subdir.id
        # In case its a new directory
        else
          # Attempt to find it in existing directories
          subdir = subdirs.build(name: subdir_name)
          # FIXME: find a better solution
          subdir.save!(validate: false)
          logger.info 'New dir: %s' % subdir.full_path
        end

        # Recreate the directory
        destroy_dirs = subdir.recreate(destroy_dirs)
      elsif File.file? subitem_path
        if dbfile = DataFile.find_existing(subitem_path, subitem_name)
          dbfile.directory = self
          dbfile.save!
        elsif (File.mtime(file) + 100).past?
          dbfile = DataFile.new
          dbfile.path = file
          dbfile.directory = self
          dbfile.save!
        end
        # TODO: handle files that are only in database
      end
    end
    return destroy_dirs
  end

  def find_existing(subdir_name, subitem_path)
    # Find by name
    if (dir = subdirs.where(name: subdir_name)).exists?
      return dir.first
    # Problem is we can't find it if haven't got that far
    else
      Directory.where(name: subdir_name).all.each do |dir|
        unless dir.path_exists?
          return dir
        end
      end
      # TODO: use filter_map here
      # NOTE: we don't use the logic from dat_file
      file_count = Dir["%s/*" % subitem_path].count{|f| File.file?(f) }
      Directory.joins(:files).group('data_files.directory_id')\
        .having('count(data_files.id) = ? and count(data_files.id) > 0', file_count).each do |dir|
          Dir.glob(File.join(dir.full_path, '*')).each do |filename|
            return false if File.size(file) != dir.files.where(name: filename).first&.size
          end
        return dir
      end
    # TODO: Find by number of files + hash of files
    end
    return false
  end

  # TODO
  def recreate_check
    true
  end

  # TODO check that you can download files
  
  def can_create? cuser
    cuser and cuser.admin?
  end

  def can_update? cuser, params = {}
    cuser and cuser.admin? and Verification.contain params, [:description, :hidden]
  end

  def can_destroy? cuser
    cuser and cuser.admin?
  end

  def self.params(params, cuser)
    params.require(:directory).permit(:description, :hidden, :name, :parent_id)
  end
end
