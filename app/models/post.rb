# frozen_string_literal: true

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

# Model for forum posts
class Post < ApplicationRecord
  include Extra

  # attr_protected :id, :updated_at, :created_at, :votes, :user_id

  scope :basic, -> { includes([{ user: %i[team profile] }, :topic]) }

  validates :topic, :user, presence: true
  validates :text, length: { in: 1..10_000 }

  before_save :parse_text
  after_destroy :remove_topics, if: proc { |post| post.topic.posts.count.zero? }

  belongs_to :user, optional: true
  belongs_to :topic, optional: true

  def number(pages, index)
    if index != -1
      pages.per_page * (pages.current_page - 1) + index + 1
    else
      topic.posts.count + 1
    end
  end

  def parse_text
    return unless text

    self.text_parsed = bbcode_to_html(text)
  end

  def remove_topics
    topic.destroy
  end

  def error_messages
    errors.full_messages.uniq
  end

  def can_create?(cuser)
    return false unless cuser

    errors.add :lock, I18n.t(:topics_locked) if topic.lock
    errors.add :user, I18n.t(:bans_mute) if cuser.banned?(Ban::TYPE_MUTE) && (topic.forum != Forum::BANS)
    errors.add :user, I18n.t(:registered_for_week) unless cuser.verified?
    (Forum.available_to(cuser, Forumer::ACCESS_REPLY).of_forum(topic.forum).first and errors.empty?)
  end

  def can_update?(cuser, params = {})
    return false unless cuser

    true if Verification.contain(params, %i[text topic_id]) && (user == cuser) || cuser.admin?
  end

  def can_destroy?(cuser)
    cuser&.admin?
  end

  def self.params(params, _cuser)
    # FIXME: check this
    params.require(:post).permit(:text, :topic_id)
  end

  def self.build_for_actor(params, actor)
    post = new(self.params(params, actor))
    post.user = actor
    post
  end
end
