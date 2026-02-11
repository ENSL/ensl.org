# frozen_string_literal: true

class AddInodeInfoToDataFilesAndDirectories < ActiveRecord::Migration[8.1]
  def change
    add_column :directories, :st_dev, :bigint, comment: 'Filesystem device ID for inode tracking'
    add_column :directories, :st_ino, :bigint,
               comment: 'Inode number for filesystem-independent directory identification'

    # Add indexes for fast lookup by inode
    add_index :directories, %i[st_dev st_ino], unique: true, name: 'index_directories_on_inode'
  end
end
