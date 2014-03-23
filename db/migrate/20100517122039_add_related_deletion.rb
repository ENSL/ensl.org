class AddRelatedDeletion < ActiveRecord::Migration
  def self.up
  	change_table :deleteds do |d|
  		d.integer :related_id
  	end
  end

  def self.down
  end
end
