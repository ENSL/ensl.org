class Forum < ActiveRecord::Base
  include Extra
  BANS = 8
  TRASH = 12

  attr_protected :id, :updated_at, :created_at

  scope :available_to,
    lambda { |user, level| {
    :select => "forums.*, groupers.user_id AS access, COUNT(f2.id) AS acl, g2.user_id",
    :joins => "LEFT JOIN forumers ON forumers.forum_id = forums.id AND forumers.access = #{level}
    LEFT JOIN forumers AS f2 ON forumers.forum_id = forums.id AND f2.access = #{level}
    LEFT JOIN groups ON forumers.group_id = groups.id
  LEFT JOIN groupers ON groupers.group_id = groups.id AND groupers.user_id = #{user.id}
    LEFT JOIN groupers g2 ON g2.group_id = #{Group::ADMINS} AND g2.user_id = #{user.id}",
    :group => "forums.id",
    :having => ["access IS NOT NULL OR acl = 0 OR g2.user_id IS NOT NULL", level]} }
  scope :public,
    :select => "forums.*",
    :joins => "LEFT JOIN forumers ON forumers.forum_id = forums.id AND forumers.access = #{Forumer::ACCESS_READ}",
    :conditions => "forumers.id IS NULL"
  scope :of_forum,
    lambda { |forum| {:conditions => {"forums.id" => forum.id}} }
  scope :ordered, :order => "position"

  has_many :topics
  has_many :posts, :through => :topics
  has_many :forumers
  has_many :groups, :through => :forumers
  has_one :forumer
  belongs_to :category

  after_create :update_position

  acts_as_readable

  def to_s
    self.title
  end

  def update_position
    update_attribute :position, self.id
  end

  def can_show? cuser
    if cuser
      Forum.available_to(cuser, Forumer::ACCESS_READ).of_forum(self).first
    else
      Forum.public.of_forum(self).first
    end
  end

  def can_create? cuser
    cuser and cuser.admin?
  end

  def can_update? cuser
    cuser and cuser.admin?
  end

  def can_destroy? cuser
    cuser and cuser.admin?
  end
end
