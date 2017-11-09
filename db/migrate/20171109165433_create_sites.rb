class CreateSites < ActiveRecord::Migration
  def change
    create_table :sites do |t|
      t.string :name
      t.references :article

      t.timestamps
    end
    add_index :sites, :name
    add_index :sites, :article_id
  end
end
