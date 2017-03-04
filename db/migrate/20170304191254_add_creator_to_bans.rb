class AddCreatorToBans < ActiveRecord::Migration
  def change
    add_column :bans, :creator_id, :integer
    add_index :bans, :creator_id
  end
end
