class AddCreatorToBans < ActiveRecord::Migration[4.2]
  def change
    add_column :bans, :creator_id, :integer
    add_index :bans, :creator_id
  end
end
