class RemoveRconFromServers < ActiveRecord::Migration[4.2]
  def up
    remove_column :servers, :rcon
  end

  def down
    add_column :servers, :rcon, :string
  end
end
