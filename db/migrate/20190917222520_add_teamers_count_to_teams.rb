class AddTeamersCountToTeams < ActiveRecord::Migration[4.2]
  def change
    add_column :teams, :teamers_count, :integer
  end
end