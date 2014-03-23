class AddGatherVotes < ActiveRecord::Migration
  def self.up
  	change_table :gathers do |g|
  		g.integer :votes, :null => false, :default => 0
  	end
  end

  def self.down
  end
end
