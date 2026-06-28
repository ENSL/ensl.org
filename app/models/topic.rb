# frozen_string_literal: true

# == Schema Information
#
# Table name: topics
#
#  id         :integer          not null, primary key
#  state      :integer          default(0), not null
#  title      :string(255)
#  created_at :datetime
#  updated_at :datetime
#  forum_id   :integer
#  user_id    :integer
#
# Indexes
#
#  index_topics_on_forum_id  (forum_id)
#  index_topics_on_user_id   (user_id)
#

class Topic < ApplicationRecord
  POSTS_PAGE = 30
  STATE_NORMAL = 0
  STATE_STICKY = 1
  LATEST_PER_PAGE = 5

  RULES = 12

  include Extra
  # attr_protected :id, :updated_at, :created_at
  attr_accessor :first_post

  belongs_to :user, optional: true
  belongs_to :forum, optional: true
  has_one :lock, as: :lockable
  has_one :latest, -> { order('id DESC') }, class_name: 'Post'
  has_many :posts, -> { order('id ASC') }, dependent: :destroy, inverse_of: :topic
  has_many :view_counts, as: :viewable, dependent: :destroy

  scope :basic, -> { includes([:latest, { forum: :forumer }, :user]) }
  scope :ordered, -> { order('state DESC, posts.id DESC') }
  scope :ordered_by_state_and_last_post, lambda {
    left_outer_joins(:posts)
      .select('topics.*, MAX(posts.created_at) AS last_post_at')
      .group('topics.id')
      .order(state: :desc)
      .order(Arel.sql('last_post_at DESC'))
  }
  scope :for_forum_overview, lambda { |forum|
    where(forum_id: forum.id)
      .joins(posts: :user)
      .includes(:lock)
      .select('topics.*, MAX(posts.created_at) AS last_post_at')
      .group('topics.id')
      .order(state: :desc)
      .order(Arel.sql('last_post_at DESC'))
  }

  validates :user_id, :forum_id, presence: true
  validates :title, length: { in: 1..50 }
  validates :first_post, length: { in: 1..10_000, on: :create }

  after_create :make_post

  acts_as_readable on: :created_at

  def self.recent_topics
    find_by_sql '
        SELECT DISTINCT topics.*
    FROM  (SELECT max(id) as max_id, topic_id
      FROM   posts
      GROUP  BY topic_id
      ORDER  BY max_id DESC
      LIMIT  200) AS T
           INNER JOIN topics
             ON T.topic_id = topics.id
           INNER JOIN forums
             ON forums.id = topics.forum_id
           LEFT OUTER JOIN forumers
            ON forumers.forum_id = forums.id
    WHERE forumers.id IS NULL
    ORDER BY T.max_id DESC
    LIMIT  5
      '
  end

  def to_s
    title
  end

  def record_view_count(ip_address, logged_in = nil, **options)
    logged_in = options.fetch(:logged_in, logged_in)
    logged_in = false if logged_in.nil?
    view_counts.find_or_create_by(ip_address: ip_address) do |vc|
      vc.logged_in = logged_in
    end
    self
  end

  def view_count
    view_counts.length
  end

  def cache_key(key)
    "/topics/#{id}/#{key}"
  end

  def cached_view_count
    Rails.cache.fetch(cache_key('view_count'), expires_in: 1.hour) do
      view_count
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

  def can_show?(cuser)
    forum&.can_show?(cuser)
  end

  def can_create?(cuser)
    return false unless cuser

    errors.add :bans, I18n.t(:bans_mute) if cuser.banned?(Ban::TYPE_MUTE) && (forum != Forum::BANS)
    errors.add :bans, I18n.t(:registered_for_week) unless cuser.verified?
    Forum.available_to(cuser, Forumer::ACCESS_TOPIC).where(id: forum_id) and errors.empty?
  end

  def can_update?(cuser)
    cuser&.admin?
  end

  def can_destroy?(cuser)
    cuser&.admin?
  end

  def last_page
    [((posts.count - 1) / POSTS_PAGE) + 1, 1].max
  end

  def states
    { STATE_NORMAL => 'Normal', STATE_STICKY => 'Sticky' }
  end

  def self.params(params, _cuser)
    params.require(:topic).permit(:state, :title, :forum_id, :user_id, :first_post)
  end
end
