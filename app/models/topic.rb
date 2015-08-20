# == Schema Information
#
# Table name: topics
#
#  id         :integer          not null, primary key
#  title      :string(255)
#  user_id    :integer
#  forum_id   :integer
#  created_at :datetime
#  updated_at :datetime
#  state      :integer          default(0), not null
#

class Topic < ActiveRecord::Base
  POSTS_PAGE = 30
  STATE_NORMAL = 0
  STATE_STICKY = 1
  LATEST_PER_PAGE = 5

  RULES = 12

  include Extra
  attr_protected :id, :updated_at, :created_at
  attr_accessor :first_post

  belongs_to :user
  belongs_to :forum
  has_one :lock, :as => :lockable
  has_one :latest, :class_name => "Post", :order => "id DESC"
  has_many :posts, :order => "id ASC", :dependent => :destroy
  has_many :view_counts, :as => :viewable, :dependent => :destroy

  scope :basic, :include => [:latest, { forum: :forumer }, :user]
  scope :ordered, :order => "state DESC, posts.id DESC"
  scope :recent,
    :conditions => "forumers.id IS NULL AND posts.id = (SELECT id FROM posts AS P WHERE P.topic_id = topics.id ORDER BY id DESC LIMIT 1)",
    :order => "posts.id DESC",
    :group => "topics.id"
  scope :latest_page,
    lambda { |page| {:limit => "#{(page-1)*LATEST_PER_PAGE}, #{(page-1)*LATEST_PER_PAGE+LATEST_PER_PAGE}"} }

  validates_presence_of :user_id, :forum_id
  validates_length_of :title, :in => 1..50
  validates_length_of :first_post, :in => 1..10000, :on => :create

  after_create :make_post

  acts_as_readable

  def self.recent_topics
    Post.order('id desc').select('DISTINCT topic_id').limit(5).map(&:topic)
  end

  def to_s
    title
  end

  def record_view_count(ip_address, logged_in = false)
    self.view_counts.create(:viewable => self, :ip_address => ip_address, :logged_in => logged_in)
    self
  end

  def view_count
    view_counts.length
  end

  def cache_key(key)
    "/topics/#{id}/#{key}"
  end

  def cached_view_count
    Rails.cache.fetch(cache_key('view_count'), expires_in: 1.hours) do
      self.view_count
    end
  end

  def cached_posts_count
    Rails.cache.fetch(cache_key('posts'), expires_in: 10.minutes) do
      posts.count - 1
    end
  end

  def make_post
    c = posts.build
    c.text = first_post
    c.user = user
    c.save!
  end

  def can_show? cuser
    forum.can_show? cuser
  end

  def can_create? cuser
    return false unless cuser
    errors.add :bans, I18n.t(:bans_mute) if cuser.banned?(Ban::TYPE_MUTE) and forum != Forum::BANS
    errors.add :bans, I18n.t(:registered_for_week) unless cuser.verified?
    (Forum.available_to(cuser, Forumer::ACCESS_TOPIC).of_forum(forum).first and errors.size == 0)
  end

  def can_update? cuser
    cuser and cuser.admin?
  end

  def can_destroy? cuser
    cuser and cuser.admin?
  end

  def last_page
    [((posts.count - 1) / POSTS_PAGE) + 1, 1].max
  end

  def states
    {STATE_NORMAL => "Normal", STATE_STICKY => "Sticky"}
  end
end
