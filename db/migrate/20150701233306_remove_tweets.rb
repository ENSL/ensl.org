class RemoveTweets < ActiveRecord::Migration
  def up
  	drop_table :tweets
  end

  def down
  end
end
