class Directory < ActiveRecord::Base
  include Extra

  ROOT = 1
  DEMOS = 5
  DEMOS_DEFAULT = 19
  DEMOS_GATHERS = 92
  MOVIES = 30
  ARTICLES = 39

  attr_protected :id, :updated_at, :created_at, :path

  belongs_to :parent, :class_name => "Directory"
  has_many :subdirs, :class_name => "Directory", :foreign_key => :parent_id
  has_many :files, :class_name => "DataFile", :order => "name"

  scope :ordered, :order => "name ASC"
  scope :filtered, :conditions => {:hidden => false}
  scope :of_parent, lambda { |parent| {:conditions => {:parent_id => parent.id}} }

  validates_length_of [:name, :path], :in => 1..255
  validates_format_of :name, :with => /\A[A-Za-z0-9]{1,20}\z/, :on => :create
  validates_length_of :name, :in => 1..25
  validates_inclusion_of :hidden, :in => [true, false]

  before_validation :init_variables
  after_create :make_path
  after_save :update_timestamp
  before_destroy :remove_files
  after_destroy :remove_path

  def to_s
    name
  end

  def init_variables
    self.path = File.join(parent.path, name.downcase)
    self.hidden = false if hidden.nil?
  end

  def make_path
    Dir.mkdir(path) unless File.exists?(path)
  end

  def update_timestamp
    self.created_at = File.mtime(path) if File.exists?(path)
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
    Dir.unlink(path) if File.exists?(path)
  end

  def process_dir
    ActiveRecord::Base.transaction do
      Dir.glob("#{path}/*").each do |file|
        if File.directory?(file)
          if dir = Directory.find_by_path(file)
            dir.save!
          else
            dir = Directory.new
            dir.name = File.basename(file)
            dir.path = file
            dir.parent = self
            dir.save!
          end
          dir.process_dir
        else
          if dbfile = DataFile.find_by_path(file)
            dbfile.directory = self
            dbfile.save!
          elsif (File.mtime(file) + 100).past?
            dbfile = DataFile.new
            dbfile.path = file
            dbfile.directory = self
            dbfile.save!
          end
        end
      end
    end
  end

  def can_create? cuser
    cuser and cuser.admin?
  end

  def can_update? cuser, params = {}
    cuser and cuser.admin? and Verification.contain params, [:description, :hidden]
  end

  def can_destroy? cuser
    cuser and cuser.admin?
  end
end
