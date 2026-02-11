class FixPrefixInFiles < ActiveRecord::Migration[8.1]
  def change
    # Some, or all files have public/files prefix, it needs to be removed
    reversible do |dir|
      dir.up do
        DataFile.where('path LIKE ?', 'public/files/%').find_each do |data_file|
          new_path = data_file.path.sub(%r{\Apublic/files/}, '')
          data_file.update_column(:path, new_path)
        end
      end
    end

    # Do same for directories
    reversible do |dir|
      dir.up do
        Directory.where('path LIKE ?', 'public/files/%').find_each do |directory|
          new_path = directory.path.sub(%r{\Apublic/files/}, '')
          directory.update_column(:path, new_path)
        end
      end
    end
  end
end
