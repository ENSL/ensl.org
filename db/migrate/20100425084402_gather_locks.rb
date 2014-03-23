class GatherLocks < ActiveRecord::Migration
  def self.up
#  	change_table :gatherers do |g|
#  		g.integer :lock_version, :default => 0
#  	end
#  	change_table :gathers do |g|
#  		g.integer :lock_version, :default => 0
#  	end
  end

  def self.down
#  	remove_column :gatherers, :lock_version
#  	remove_column :gathers, :lock_version
  end
end
