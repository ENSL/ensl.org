# frozen_string_literal: true

class RenameDataFileDescriptionToTitleAndAddDescription < ActiveRecord::Migration[8.1]
  def change
    rename_column :data_files, :description, :title
    add_column :data_files, :description, :text, default: '', null: false
  end
end
