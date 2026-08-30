# frozen_string_literal: true

class RemoveInvalidBansAndTweetComments < ActiveRecord::Migration[8.1]
  def up
    invalid_bans = Ban.where('ban_type != ? AND user_id IS NULL AND server_id IS NULL', Ban::TYPE_SERVER)
    say_with_time("Removing #{invalid_bans.count} invalid Ban rows") do
      invalid_bans.delete_all
    end

    stale_tweet_comments = Comment.where(commentable_type: 'Tweet')
    say_with_time("Removing #{stale_tweet_comments.count} stale Tweet comments") do
      stale_tweet_comments.delete_all
    end
  end

  def down
    # This migration removes legacy data that is no longer valid. There is no safe
    # reverse operation for the actual rows that were deleted, so we intentionally
    # leave this as a destructive no-op rollback.
  end
end
