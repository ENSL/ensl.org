class AddCategoryIdToServerVersions < ActiveRecord::Migration
  def change
    change_table :server_versions do |s|
      s.integer :category_id
    end
  end
end
