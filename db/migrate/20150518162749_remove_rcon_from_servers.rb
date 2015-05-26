class RemoveRconFromServers < ActiveRecord::Migration
  def up
    remove_column :servers, :rcon
  end

  def down
    add_column :servers, :rcon, :string
  end
end
