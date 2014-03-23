class CreateFirms < ActiveRecord::Migration
  def self.up
    create_table :firms do |t|
      t.string :name
      t.string :y_code
      t.string :email
      t.string :website
      t.string :phone
      t.string :address
      t.integer :zipcode
      t.string :town
      t.integer :owner
      t.string :opentime

      t.timestamps
    end
  end

  def self.down
    drop_table :firms
  end
end
