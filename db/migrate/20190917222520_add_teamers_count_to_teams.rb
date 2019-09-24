class AddTeamersCountToTeams < ActiveRecord::Migration
  def change
    add_column :teams, :teamers_count, :integer
  end
end