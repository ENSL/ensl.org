class CreateGatherServers < ActiveRecord::Migration
  def self.up
    create_table :gather_servers do |t|
    	t.references :gather
    	t.references :server
    	t.integer :votes
      t.timestamps
    end
  end

  def self.down
    drop_table :gather_servers
  end
end
