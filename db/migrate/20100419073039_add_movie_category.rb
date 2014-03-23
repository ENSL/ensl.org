class AddMovieCategory < ActiveRecord::Migration
  def self.up
  	change_table :movies do |m|
  		m.integer :category_id
  	end
  end

  def self.down
  end
end
