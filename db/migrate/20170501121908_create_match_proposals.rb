class CreateMatchProposals < ActiveRecord::Migration
  def change
    create_table :match_proposals do |t|
      t.references :match
      t.references :team
      t.integer :status
      t.datetime :proposed_time

      t.timestamps
    end
    add_index :match_proposals, :match_id
    add_index :match_proposals, :team_id
  end
end
