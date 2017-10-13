class CreateMatchProposals < ActiveRecord::Migration
  def up
    create_table :match_proposals do |t|
      t.references :match, index: true, forign_key: true
      t.references :team, forign_key: true
      t.datetime :proposed_time
      t.integer :status
    end

    add_index :match_proposals, :status
  end

  def down; end
end
