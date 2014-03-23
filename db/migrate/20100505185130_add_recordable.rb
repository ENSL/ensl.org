class AddRecordable < ActiveRecord::Migration
  def self.up
  	change_table :servers do |m|
  		m.remove :match_id
  		m.string :recordable_type
  		m.integer :recordable_id
  	end
  end

  def self.down
  end
end
