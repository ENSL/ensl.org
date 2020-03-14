class HasViewCountMigration < ActiveRecord::Migration
  def self.up
    create_table :view_counts do |t|
      t.references :viewable, :polymorphic => true
      t.string :ip_address
      t.boolean :logged_in
      t.datetime :created_at
    end
  end

  def self.down
    drop_table :view_counts
  end
end