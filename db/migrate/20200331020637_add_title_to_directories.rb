class AddTitleToDirectories < ActiveRecord::Migration[6.0]
  def change
    change_table :directories do |m|
      m.string :title
    end
    Directory.all.each do |dir|
      dir.title = dir.name
      dir.name = File.basename(dir.path)
      dir.save!
    end
  end
end
