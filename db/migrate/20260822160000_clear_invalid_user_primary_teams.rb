# frozen_string_literal: true

class ClearInvalidUserPrimaryTeams < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL.squish
      UPDATE users
      LEFT JOIN teams ON teams.id = users.team_id
      SET users.team_id = NULL
      WHERE users.team_id IS NOT NULL
        AND (
          teams.id IS NULL
          OR NOT EXISTS (
            SELECT 1
            FROM teamers
            WHERE teamers.user_id = users.id
              AND teamers.team_id = users.team_id
              AND teamers.rank <> -1
          )
        )
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
