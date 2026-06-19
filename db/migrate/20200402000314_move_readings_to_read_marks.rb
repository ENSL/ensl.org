# frozen_string_literal: true

class MoveReadingsToReadMarks < ActiveRecord::Migration[4.2][6.0]
  def change
    execute "INSERT IGNORE INTO read_marks (readable_type, readable_id, reader_type, reader_id, timestamp)
            SELECT readable_type, readable_id, 'User', user_id,
              COALESCE(MAX(updated_at), MAX(created_at))
            FROM readings GROUP BY readable_type, readable_id, user_id;"
  end
end
