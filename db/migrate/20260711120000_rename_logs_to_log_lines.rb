# frozen_string_literal: true

class RenameLogsToLogLines < ActiveRecord::Migration[8.1]
  def change
    # MySQL/MariaDB automatically renames indexes to match the new table name.
    rename_table :logs, :log_lines
  end
end
