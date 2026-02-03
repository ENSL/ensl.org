class AddVersionToGathers < ActiveRecord::Migration[8.1]
  def change
    add_column :gathers, :version, :integer, null: false, default: 0
    add_index :gathers, :version
  end
end
