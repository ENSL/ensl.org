class CreateCustomUrls < ActiveRecord::Migration[4.2]
  def change
    create_table :custom_urls do |t|
      t.string :name
      t.references :article

      t.timestamps
    end
    add_index :custom_urls, :name
    add_index :custom_urls, :article_id
  end
end
