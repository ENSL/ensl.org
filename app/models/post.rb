# == Schema Information
#
# Table name: posts
#
#  id          :integer          not null, primary key
#  text        :text(65535)
#  text_parsed :text(65535)
#  created_at  :datetime
#  updated_at  :datetime
#  topic_id    :integer
#  user_id     :integer
#
# Indexes
#
#  index_posts_on_topic_id  (topic_id)
#  index_posts_on_user_id   (user_id)
#

class Post < ActiveRecord::Base
  include Extra

  #attr_protected :id, :updated_at, :created_at, :votes, :user_id

  scope :basic, -> {includes([{:user => [:team, :profile]}, :topic])}

  validates_presence_of :topic, :user
  validates_length_of :text, :in => 1..10000

  before_save :parse_text
  after_destroy :remove_topics, :if => Proc.new {|post| post.topic.posts.count == 0}

  belongs_to :user, :optional => true
  belongs_to :topic, :optional => true

  def number pages, i
    if i != -1
      pages.per_page * (pages.current_page - 1) + i + 1
    else
      topic.posts.count + 1
    end
  end
  
  def parse_text
    if self.text
      self.text_parsed = bbcode_to_html(self.text)
    end
  end

  def remove_topics
    topic.destroy
  end

  def error_messages
    self.errors.full_messages.uniq
  end

  def can_create? cuser
    return false unless cuser
    errors.add :lock, I18n.t(:topics_locked) if topic.lock
    errors.add :user, I18n.t(:bans_mute) if cuser.banned?(Ban::TYPE_MUTE) and topic.forum != Forum::BANS
    errors.add :user, I18n.t(:registered_for_week) unless cuser.verified?
    (Forum.available_to(cuser, Forumer::ACCESS_REPLY).of_forum(topic.forum).first and errors.size == 0)
  end

  def can_update? cuser, params = {}
    return false unless cuser
    true if Verification.contain(params, [:text, :topic_id]) and user == cuser or cuser.admin?
  end

  def can_destroy? cuser
    cuser and cuser.admin?
  end

  def self.params(params, cuser)
    # FIXME: check this
    params.require(:post).permit(:text, :topic_id)
  end
end
