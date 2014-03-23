class CreateDeleteds < ActiveRecord::Migration
  def self.up
    create_table :deleteds do |t|
    	t.integer :deletable_id
    	t.string :deletable_type
      t.references :user
      t.text :reason
      t.timestamps
    end
  end

  def self.down
    drop_table :deleteds
  end
end
