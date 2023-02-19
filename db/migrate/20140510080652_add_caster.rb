class AddCaster < ActiveRecord::Migration[4.2]
  def change
  	change_table :matches do |m|
  	  m.string :caster_id
  	end
  end
end
