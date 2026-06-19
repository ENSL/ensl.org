# frozen_string_literal: true

class AddTitleToDirectories < ActiveRecord::Migration[4.2][6.0]
  def change
    change_table :directories do |m|
      m.string :title
    end

    # Migrate existing data
    Directory.find_each(batch_size: 200) do |dir|
      new_title = dir.name
      new_name = dir.path.present? ? File.basename(dir.path) : dir.name
      dir.update_columns(title: new_title, name: new_name)
    end
  end
end
