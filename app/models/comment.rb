# frozen_string_literal: true

# == Schema Information
#
# Table name: comments
#
#  id               :integer          not null, primary key
#  commentable_type :string(255)
#  text             :text(65535)
#  text_parsed      :text(65535)
#  created_at       :datetime
#  updated_at       :datetime
#  commentable_id   :integer
#  user_id          :integer
#
# Indexes
#
#  index_comments_on_commentable_type                     (commentable_type)
#  index_comments_on_commentable_type_and_commentable_id  (commentable_type,commentable_id)
#  index_comments_on_commentable_type_and_id              (commentable_type,id)
#  index_comments_on_user_id                              (user_id)
#

class Comment < ApplicationRecord
  include Extra

  # attr_protected :id, :updated_at, :created_at, :user_id

  scope :with_userteam, -> { includes({ user: :team }) }
  scope :recent, ->(n) { order('id DESC').limit(n) }
  scope :recent5, -> { order('id DESC').limit(5).group('commentable_id, commentable_type') }
  scope :filtered, -> { where.not(commentable_type: 'Issue') }
  scope :ordered, -> { order('id ASC') }

  belongs_to :user, optional: true
  belongs_to :commentable, polymorphic: true, optional: true

  validates :commentable, :user, presence: true
  validates :text, length: { in: 1..10_000 }

  before_save :parse_text

  def parse_text
    return unless text

    self.text_parsed = bbcode_to_html(text)
  end

  def after_create
    #		if commentable_type == "Movie" or commentable_type == "Article" and commentable.user and commentable.user.profile.notify_own_stuff
    #			Notifications.deliver_comments commentable.user, commentable
    #		end
  end

  def can_create?(cuser)
    return false unless cuser

    # errors.add_to_base I18n.t(:comments_locked) if !commentable.lock.nil? and commentable.lock
    errors.add :base, I18n.t(:bans_mute) if cuser.banned? Ban::TYPE_MUTE
    errors.add :base, I18n.t(:registered_for_week) unless cuser.verified?
    errors.count.zero?
  end

  def can_update?(cuser)
    cuser && (user == cuser || cuser.admin?)
  end

  def can_destroy?(cuser)
    cuser&.admin?
  end

  def self.params(params, _cuser)
    params.require(:comment).permit(:text, :user_id, :commentable_type, :commentable_id)
  end
end
