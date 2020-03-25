# == Schema Information
#
# Table name: forums
#
#  id          :integer          not null, primary key
#  description :string(255)
#  position    :integer
#  title       :string(255)
#  created_at  :datetime
#  updated_at  :datetime
#  category_id :integer
#
# Indexes
#
#  index_forums_on_category_id  (category_id)
#

class Forum < ActiveRecord::Base
  include Extra
  
  BANS = 8
  TRASH = 12

  #attr_protected :id, :updated_at, :created_at

  scope :public_forums, -> { select("forums.*")
                     .joins("LEFT JOIN forumers ON forumers.forum_id = forums.id AND forumers.access = #{Forumer::ACCESS_READ}")
                     .where("forumers.id IS NULL") }
  scope :of_forum, -> (forum) { where("forums.id", forum.id) }
  scope :ordered, -> { order("position") }

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
      Forum.public_forums.where(id: self.id).exists?
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

  def self.available_to cuser, level
    user_has_access =
      Forum .joins("JOIN forumers ON forumers.forum_id = forums.id
                            AND forumers.access =  #{level}")
      .joins("JOIN groups ON forumers.group_id = groups.id")
      .joins("JOIN groupers ON groupers.group_id = groups.id
                          AND groupers.user_id = #{cuser.id}")

    is_admin = Grouper.where(user_id: cuser, group_id: Group::ADMINS)
    Forum.where("EXISTS (#{is_admin.to_sql}) OR
                id IN (SELECT q.id from (#{user_has_access.to_sql}) q ) OR
                id IN (SELECT q.id from (#{Forum.public_forums.to_sql}) q )")
  end

  def self.params(params, cuser)
    params.require(:forum).permit(:description, :position, :title, :category_id)
  end
end
