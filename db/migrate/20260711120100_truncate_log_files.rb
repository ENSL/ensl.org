# frozen_string_literal: true

class TruncateLogFiles < ActiveRecord::Migration[8.1]
  def up
    execute 'TRUNCATE TABLE log_files'
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
