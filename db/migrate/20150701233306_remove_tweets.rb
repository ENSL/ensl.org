# frozen_string_literal: true

class RemoveTweets < ActiveRecord::Migration[4.2]
  def up
    drop_table :tweets
  end

  def down; end
end
