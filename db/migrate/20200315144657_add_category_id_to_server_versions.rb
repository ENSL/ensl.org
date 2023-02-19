class AddCategoryIdToServerVersions < ActiveRecord::Migration[4.2][4.2]
  def change
    change_table :server_versions do |s|
      s.integer :category_id
    end
  end
end
