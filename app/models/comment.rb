# == Schema Information
#
# Table name: comments
#
#  id               :integer          not null, primary key
#  text             :text
#  user_id          :integer
#  commentable_type :string(255)
#  commentable_id   :integer
#  created_at       :datetime
#  updated_at       :datetime
#  text_parsed      :text
#

class Comment < ActiveRecord::Base
  include Extra

  attr_protected :id, :updated_at, :created_at, :user_id

  scope :with_userteam, :include => {:user => :team}
  scope :recent, :order => "id DESC", :limit => 10
  scope :recent3, :order => "id DESC", :limit => 3
  scope :recent5, :order => "id DESC", :limit => 5, :group => "commentable_id, commentable_type"
  scope :filtered, :conditions => ["commentable_type != 'Issue'"]
  scope :ordered, :order => "id ASC"

  belongs_to :user
  belongs_to :commentable, :polymorphic => true

  validates_presence_of :commentable, :user
  validates_length_of :text, :in => 1..10000

  before_save :parse_text

  def parse_text
    if self.text
      self.text_parsed = bbcode_to_html(self.text)
    end
  end

  def after_create
    #		if commentable_type == "Movie" or commentable_type == "Article" and commentable.user and commentable.user.profile.notify_own_stuff
    #			Notifications.deliver_comments commentable.user, commentable
    #		end
  end

  def can_create? cuser
    return false unless cuser
    #errors.add_to_base I18n.t(:comments_locked) if !commentable.lock.nil? and commentable.lock
    errors.add_to_base I18n.t(:bans_mute) if cuser.banned? Ban::TYPE_MUTE
    errors.add_to_base I18n.t(:registered_for_week) unless cuser.verified?
    return errors.count == 0
  end

  def can_update? cuser
    cuser and user == cuser or cuser.admin?
  end

  def can_destroy? cuser
    cuser and cuser.admin?
  end
end
