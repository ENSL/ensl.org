class AddMoreIndexes < ActiveRecord::Migration
  def self.up
  	add_index :pcws, :match_time
  	add_index :movies, :status
  	add_index :gatherers, :gather_id
  	add_index :comments, [:commentable_type, :id]
  end

  def self.down
  end
end
