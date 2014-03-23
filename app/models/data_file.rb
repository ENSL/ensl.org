require File.join(Rails.root, 'vendor', 'plugins', 'acts_as_rateable', 'init.rb')
require 'digest/md5'

class DataFile < ActiveRecord::Base
  include Extra

  MEGABYTE = 1048576

  attr_accessor :related_id
  attr_protected :id, :updated_at, :created_at, :path, :size, :md5

  scope :recent, :order => "created_at DESC", :limit => 8
  scope :demos, :order => "created_at DESC", :conditions => ["directory_id IN (SELECT id FROM directories WHERE parent_id = ?)", Directory::DEMOS]
  scope :ordered, :order => "created_at DESC"
  scope :movies, :order => "created_at DESC", :conditions => {:directory_id => Directory::MOVIES}
  scope :not, lambda { |file| {:conditions => ["id != ?", file.id]} }
  scope :unrelated, :conditions => "related_id is null"

  has_many :related_files, :class_name => "DataFile", :foreign_key => :related_id
  has_many :comments, :as => :commentable
  has_one :movie, :foreign_key => :file_id, :dependent => :destroy
  has_one :preview, :class_name => "Movie", :foreign_key => :preview_id, :dependent => :nullify
  has_one :match, :foreign_key => :demo_id
  belongs_to :directory
  belongs_to :related, :class_name => "DataFile"
  belongs_to :article

  validates_length_of [:description, :path], :maximum => 255

  before_save :process_file
  after_create :create_movie, :if => Proc.new {|file| file.directory_id == Directory::MOVIES and !file.location.include?("_preview.mp4") }
  after_save :update_relations, :if => Proc.new { |file| file.related_id_changed? and related_files.count > 0 }

  acts_as_rateable
  mount_uploader :name, FileUploader

  def to_s
    (description.nil? or description.empty?) ? File.basename(name.to_s) : description
  end

  def md5_s
    md5.upcase
  end

  def extra_url
    url.to_s.gsub(/^\/files/, "http://extra.ensl.org/static")
  end

  def size_s
    (size.to_f/MEGABYTE).round(2).to_s + " MB"
  end

  def location
    name.current_path
  end

  def url
    name.url
  end

  def process_file
    self.md5 = "e948c22100d29623a1df48e1760494df"
    if article
      self.directory_id = Directory::ARTICLES
    end

    if File.exists?(location) and (size != File.size(location) or created_at != File.mtime(location))
      self.md5 = Digest::MD5.hexdigest(File.read(location))
      self.size = File.size(location)
      self.created_at = File.mtime(location)
    end

    if path.nil? or directory_id_changed?
      self.path = File.join(directory.path, File.basename(name.to_s))
    end

    if !new_record? and directory_id_changed? and File.exists?(name.current_path)
      FileUtils.mv(location, path)
    end

    if description.nil? or description.empty?
      self.description = File.basename(location).gsub(/[_\-]/, " ").gsub(/\.\w{1,5}$/, "")
      self.description = description.split(/\s+/).each{ |word| word.capitalize! }.join(' ')
    end

    if match
      self.description = match.contester1.to_s + " vs " + match.contester2.to_s
    end

    if location.include? "_preview.mp4" and !related
      stripped = location.gsub(/_preview\.mp4/, "")
      DataFile.all(:conditions => ["path LIKE ?", stripped + "%"]).each do |r|
        if r.location.match(/#{stripped}\.\w{1,5}$/)
          self.related = r
        end
      end
    end

    if movie and (new_record? or md5_changed?)
      movie.get_length
    end
  end

  def create_movie
    movie = Movie.new
    movie.file = self
    movie.make_snapshot 5
    movie.save
  end

  def update_relations
    related_files.each do |rf|
      rf.related = self.related
      rf.save
    end
  end

  def rateable? user
    user and !rated_by?(user)
  end

  def can_create? cuser
    return false unless cuser
    return false if cuser.banned?(Ban::TYPE_MUTE)
    (cuser.admin? or \
     (article and article.can_create? cuser) or \
     (directory_id == Directory::MOVIES and cuser.has_access? Group::MOVIES))
  end

  def can_update? cuser
    cuser and cuser.admin? or (article and article.can_create? cuser)
  end

  def can_destroy? cuser
    cuser and cuser.admin? or (article and article.can_create? cuser)
  end
end
