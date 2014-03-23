class AddBracketName < ActiveRecord::Migration
  def self.up
  	change_table :brackets do |b|
  		b.string :name
  	end
  end

  def self.down
  end
end
