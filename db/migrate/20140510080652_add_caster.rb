class AddCaster < ActiveRecord::Migration
  def change
  	change_table :matches do |m|
  	  m.string :caster_id
  	end
  end
end
