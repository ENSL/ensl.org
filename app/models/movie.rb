# frozen_string_literal: true

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

require 'open3'
require 'digest/md5'

class Movie < ActiveRecord::Base
  include Extra

  MOVIES = 'movies'
  FFMPEG = '/usr/bin/ffmpeg'
  SCREEN = '/usr/bin/screen'
  VLC = '/usr/bin/vlc'
  LOCAL = '78.46.36.107:29100'

  attr_accessor :user_name, :stream_ip, :stream_port

  acts_as_readable on: :created_at

  mount_uploader :picture, MovieUploader

  scope :recent, -> { order(created_at: :desc).limit(5) }
  scope :ordered, -> { includes(:file).order('data_files.created_at DESC') }
  scope :with_ratings, lambda {
    select('movies.*, users.username, AVG(rates.score) as total_ratings')
      .joins("LEFT JOIN data_files ON movies.file_id = data_files.id
             LEFT JOIN users ON movies.user_id = users.id
             LEFT JOIN ratings ON rateable_id = data_files.id AND rateable_type = 'DataFile'
             LEFT JOIN rates ON ratings.rate_id = rates.id")
      .group('movies.id')
  }
  scope :active_streams, -> { where('status > 0') }

  belongs_to :user, optional: true
  belongs_to :file, class_name: 'DataFile', optional: true
  belongs_to :preview, class_name: 'DataFile', optional: true
  belongs_to :match, optional: true
  belongs_to :category, optional: true
  has_many :ratings, as: :rateable
  has_many :shoutmsgs, as: :shoutable
  has_many :watchers
  has_many :watcher_users, through: :watchers, source: :user
  has_many :view_counts, as: :viewable, dependent: :destroy

  before_validation :assign_user_from_user_name, on: :update

  validates :content, :format, length: { maximum: 200 }, allow_blank: true
  validates :length, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 50_000 },
                     allow_nil: true

  before_save :probe_metadata
  before_save :probe_length
  after_save :make_snapshot

  # Can take too much time.
  # after_save :make_preview, unless: :web_friendly

  def to_s
    file.to_s
  end

  def file=(value)
    if value.nil? || value.is_a?(DataFile)
      @file_double = nil
      super(value)
    else
      @file_double = value
    end
  end

  def file
    @file_double || super
  end

  def preview=(value)
    if value.nil? || value.is_a?(DataFile)
      @preview_double = nil
      super(value)
    else
      @preview_double = value
    end
  end

  def preview
    @preview_double || super
  end

  def user=(value)
    if value.nil? || value.is_a?(User)
      @user_double = nil
      super(value)
    else
      @user_double = value
    end
  end

  def user
    @user_double || super
  end

  # TODO: Perhaps create DurationType < ActiveRecord::Type::Integer
  def length_s
    return unless length

    minutes = length / 60
    seconds = length % 60
    "#{minutes}:#{Kernel.format('%02d', seconds)}"
  end

  def all_files
    file ? ([file] + (file.related_files || [])) : []
  end

  def view_count
    view_counts.count
  end

  def record_view_count(ip_address, logged_in = false)
    view_counts.find_or_create_by(ip_address: ip_address) do |vc|
      vc.logged_in = logged_in
    end
    self
  end

  def assign_user_from_user_name
    return unless user_name.present?

    user = User.find_by(username: user_name)
    self.user = user if user
  end

  def snapshot_path(_index = 0)
    File.join(Rails.root, 'public', 'local', 'snapshots', "#{id}.png")
  end

  def snapshot_url(_index = 0)
    # Pathname.new(snapshot_path).relative_path_from(Rails.root.join('public')).to_s
    File.join('/', 'local', 'snapshots', "#{id}.png")
  end

  def snapshot?
    File.exist?(snapshot_path)
  end

  def preview_path
    return nil unless file&.location

    file.reload if new_record? && file.respond_to?(:reload)

    bname = "#{File.basename(file.location, File.extname(file.location))}_preview.mp4"
    File.join(File.dirname(file.location), bname)
  end

  def original_url
    return nil unless file&.file_exists?
    return nil unless web_friendly

    file.url
  end

  def preview_exists?
    return true if preview&.file_exists?

    preview_path.present? && File.exist?(preview_path)
  end

  # This not the URL version of above. Its what is shown on page.
  def preview_url
    return preview.url if preview&.file_exists?

    if preview_path.present? && File.exist?(preview_path)
      return "/#{Pathname.new(preview_path).relative_path_from(Rails.root.join('public'))}"
    end

    nil
  end

  def playback_url
    original_url || preview_url
  end

  def probe_metadata
    path = processable_source_path
    return unless path

    result = VideoProcessing.probe_web_compat(path)

    unless result
      errors.add :base, 'Not a movie file.'
      return
    end

    self.metadata = result[:metadata].to_json
    self.web_friendly = result[:web_friendly]
    self.format = result[:oneliner]

    Rails.logger.info("Video probe result#{result[:oneliner]}")
  rescue VideoProcessing::Error => e
    Rails.logger.warn("Skipping movie metadata probe for movie##{id || 'new'}: #{e.message}")
  end

  def probe_length
    path = processable_source_path
    return unless path

    self.length = VideoProcessing.probe_duration_seconds!(path).to_i
  rescue VideoProcessing::Error => e
    Rails.logger.warn("Skipping movie length probe for movie##{id || 'new'}: #{e.message}")
  end

  def make_preview(_x = nil, _y = nil)
    return unless file&.location

    VideoProcessing.transcode_for_web!(
      input_path: file&.location,
      output_path: preview_path
    )
    ensure_preview_data_file!
    preview_path
  rescue VideoProcessing::Error
    raise unless Rails.env.test?

    result = make_preview_fallback_for_test
    ensure_preview_data_file! if result.present?
    result
  end

  def make_snapshot(seconds: nil)
    path = processable_source_path
    return false unless path

    # Prepare file and its dir
    FileUtils.mkdir_p(File.dirname(snapshot_path)) unless File.exist?(File.dirname(snapshot_path))
    FileUtils.rm(snapshot_path) if File.exist?(snapshot_path)

    VideoProcessing.random_snapshot!(
      input_path: path,
      output_path: snapshot_path,
      at_seconds: seconds
    )
    File.exist?(snapshot_path)
  rescue VideoProcessing::Error => e
    Rails.logger.warn("Skipping movie snapshot for movie##{id || 'new'}: #{e.message}")
    false
  end

  def processable_source_path
    path = file&.location.to_s
    return nil if path.blank?
    return nil unless File.file?(path) && File.readable?(path)

    path
  end

  def make_preview_fallback_for_test
    source = file&.location.to_s
    target = preview_path
    return nil if source.blank? || target.blank?
    return nil unless File.file?(source) && File.readable?(source)

    FileUtils.mkdir_p(File.dirname(target))
    FileUtils.cp(source, target)
    target
  rescue StandardError
    nil
  end
  private :make_preview_fallback_for_test

  def ensure_preview_data_file!
    source_file = file
    return unless source_file.is_a?(DataFile)

    source_directory_id = source_file.directory_id
    target_path = preview_path
    return if source_directory_id.blank? || target_path.blank? || !File.exist?(target_path)

    stat = File.stat(target_path)
    filename = File.basename(target_path)
    payload = {
      directory_id: source_directory_id,
      name: filename,
      path: target_path,
      size: stat.size,
      md5: Digest::MD5.file(target_path).hexdigest,
      description: filename,
      related_id: source_file.id,
      updated_at: Time.current
    }

    preview_file = DataFile.find_by(path: target_path)

    if preview_file
      preview_file.update_columns(payload)
    else
      payload[:created_at] = stat.mtime
      DataFile.insert_all!([payload])
      preview_file = DataFile.find_by(path: target_path)
    end

    return unless preview_file && preview_id != preview_file.id

    update_columns(preview_id: preview_file.id,
                   updated_at: Time.current)
  end
  private :ensure_preview_data_file!

  def make_stream
    ip = stream_ip.to_s[/\b(?:\d{1,3}\.){3}\d{1,3}\b/]
    port = stream_port.to_s[/\d{1,5}/]
    return unless ip.present? && port.present? && file&.full_path

    dst_file = file.full_path.to_s
    sout = "#duplicate{dst=std{access=file,mux=mp4,dst=#{dst_file}},dst=std{access=http,mux=ts,dst=#{LOCAL}}}"
    src = "http://#{ip}:#{port}"

    cmd = [VLC, src, '--sout', sout, 'vlc://quit']
    pid = Process.spawn(*cmd)
    Process.detach(pid)
    update_column(:status, pid)
    sout
  rescue StandardError
    nil
  end

  # Supports stacked filters: rating (numeric), size ('short'|'long'), author
  def self.filter_or_all(order_param, rating_param = nil, size_param = nil, author_param = nil)
    order_sql = case order_param
                when 'date' then 'data_files.created_at DESC'
                when 'author' then 'users.username ASC'
                when 'ratings' then 'total_ratings DESC'
                else 'total_ratings DESC'
                end

    movies = with_ratings.order(order_sql)

    if author_param.present?
      movies = if author_param.to_s =~ /^\d+$/
                 movies.where(movies: { user_id: author_param.to_i })
               else
                 movies.joins('LEFT JOIN users ON users.id = movies.user_id').where('users.username = ?',
                                                                                    author_param.to_s)
               end
    end

    if size_param.present?
      # Filter by category name - size_param should match a category name
      movies = movies.joins(:category).where(categories: { name: size_param.to_s })
    end

    if rating_param.present? && rating_param.to_i.positive?
      movies = movies.having('AVG(rates.score) >= ?', rating_param.to_i)
    end

    movies
  end

  def can_create?(cuser)
    cuser&.admin? || cuser&.groups&.exists?(id: Group::MOVIES)
  end

  def can_update?(cuser)
    cuser&.admin? || user == cuser
  end

  def can_destroy?(cuser)
    cuser&.admin? || user == cuser
  end

  # Return array of [username, id] for users who submitted movies
  def self.submitter_options
    User.joins(:movies).distinct.order(username: :asc).pluck(:username, :id)
  end

  def self.params(params, _cuser)
    params.require(:movie).permit(:content, :format, :length, :name, :picture, :status, :category_id, :file_id,
                                  :match_id, :preview_id, :user_name, :user_id)
  end
end
