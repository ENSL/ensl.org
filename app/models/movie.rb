# == Schema Information
#
# Table name: movies
#
#  id          :integer          not null, primary key
#  content     :string(255)
#  format      :string(255)
#  length      :integer
#  name        :string(255)
#  picture     :string(255)
#  status      :integer
#  created_at  :datetime
#  updated_at  :datetime
#  category_id :integer
#  file_id     :integer
#  match_id    :integer
#  preview_id  :integer
#  user_id     :integer
#
# Indexes
#
#  index_movies_on_file_id     (file_id)
#  index_movies_on_match_id    (match_id)
#  index_movies_on_preview_id  (preview_id)
#  index_movies_on_status      (status)
#  index_movies_on_user_id     (user_id)
#

class Movie < ActiveRecord::Base
  include Extra

  MOVIES = "movies"
  FFMPEG = "/usr/local/bin/ffmpeg"
  SCREEN = "/usr/bin/screen"
  VLC = "/usr/bin/vlc"
  LOCAL = "78.46.36.107:29100"

  #attr_protected :id, :updated_at, :created_at
  attr_accessor :user_name, :name, :stream_ip, :stream_port

  scope :recent, -> { limit(5) }
  scope :ordered, -> {  include("file").
    order("data_files.created_at DESC") }
  scope :with_ratings, -> {
    select("movies.*, users.username, AVG(rates.score) as total_ratings")
    .joins("LEFT JOIN data_files ON movies.file_id = data_files.id
            LEFT JOIN users ON movies.user_id = users.id
            LEFT JOIN ratings ON rateable_id = data_files.id AND rateable_type = 'DataFile'
            LEFT JOIN rates ON ratings.rate_id = rates.id")
    .group("movies.id") }
  scope :active_streams, -> { where("status > 0") }

  belongs_to :user
  belongs_to :file, :class_name => "DataFile"
  belongs_to :preview, :class_name => "DataFile"
  belongs_to :match
  belongs_to :category
  has_many :ratings, :as => :rateable
  has_many :shoutmsgs, :as => :shoutable
  has_many :watchers
  has_many :watcher_users, :through => :watchers, :source => :user

  validates_length_of [:content, :format], :maximum => 100, :allow_blank => true
  validates_inclusion_of :length, :in => 0..50000, :allow_blank => true, :allow_nil => true
  validates_presence_of :file

  mount_uploader :picture, MovieUploader

  has_view_count
  acts_as_readable

  def to_s
    file.to_s
  end

  def length_s
    (length/60).to_s + ":" +  (length%60).to_s if length
  end

  def get_user
    user_id ? User.find(user_id) : ""
  end

  def get_length
    if m = (`exiftool -Duration "#{file.full_path}" 2> /dev/null | grep -o '[0-9]*:[0-9]*' | tail -n1`.match(/([0-9]*):([0-9]*)/))
      update_attribute :length, m[1].to_i*60 + m[2].to_i
    end
  end

  def all_files
    file ? ([file] + file.related_files) : []
  end

  def before_validation
    if user_name and !user_name.empty?
      self.user = User.find_by_username(user_name)
      else
      self.user = nil
    end
    #if file.nil? and match and stream_ip and stream_port
    #	build_file
    #	self.file.directory = Directory.find(Directory::MOVIES)
    #	self.file.path = File.join(self.file.directory.path, match.demo_name + ".mp4")
    #	self.file.description = match.contest.short_name + ": " + match.contester1.to_s + " vs " + match.contester2.to_s
    #	FileUtils.touch(self.file.path)
    #	self.file.save!
    #	make_stream
    #end
  end

  def make_preview x, y
    result = file.full_path.gsub(/\.\w{3}$/, "") + "_preview.mp4"
    params = "-vcodec libx264 -vpre hq -b 1200k -bt 1200k -acodec libmp3lame -ab 128k -ac 2"
    cmd = "#{SCREEN} -d -m #{FFMPEG} -y -i \"#{file.full_path}\" #{params} \"#{result}\""
    system cmd
    cmd
  end

  def make_snapshot secs
    image = File.join(Rails.root, "public", "images", MOVIES, id.to_s + ".png")
    params = "-ss #{secs} -vcodec png -vframes 1 -an -f rawvideo -s 160x120"
    Movie.update_all({:picture => "#{id}.png"}, {:id => id})
    cmd = "#{FFMPEG} -y -i \"#{file.full_path}\" #{params} \"#{image}\""
    system cmd
    cmd
  end

  def make_stream
    ip = stream_ip.match(/[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/)[0]
    port = stream_port.match(/[0-9]{1,5}/)[0]
    cmd = "#{SCREEN} -d -m #{VLC} http://#{ip}:#{port} --sout \"#duplicate{dst=std{access=file,mux=mp4,dst=#{file.full_path}},dst=std{access=http,mux=ts,dst=#{LOCAL}}}\" vlc://quit"
      system cmd
    update_attribute :status, $?.pid
    cmd
  end

  def self.filter_or_all order, filter
    order = case  order
      when "date" then "data_files.created_at DESC"
      when "author" then "users.username ASC"
      when "ratings" then "total_ratings DESC"
      else "total_ratings DESC"
    end

    # FIXME: use new system
    #movies = []
    #if filter
    #  Movie.index.order(order).each do |movie|
    #    if movie.file and movie.file.average_rating_round >= filter.to_i
    #      movies << movie
    #    end
    #  end
    #  return movies
    #else
      return with_ratings.order(order)
    #end
  end

  #def update_status
  #	if status and status > 0
  #		begin
  #			Process.getpgid(status) != -1
  #		rescue Errno::ESRCH
  #			update_attribute :status, 0
  #		end
  #	end
  #end

  def can_create? cuser
    cuser and cuser.admin? or cuser.groups.exists? :id => Group::MOVIES
  end

  def can_update? cuser
    cuser and cuser.admin? or user == cuser
  end

  def can_destroy? cuser
    cuser and cuser.admin?
  end

  def self.params(params, cuser)
    params.require(:movie).permit(:content, :format, :length, :name, :picture, :status, :category_id, :file_id, :match_id, :preview_id, :user_id)
  end
end
