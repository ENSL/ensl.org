class MoveReadingsToReadMarks < ActiveRecord::Migration[6.0]
  def change
    # execute "TRUNCATE read_marks"
    execute "INSERT INTO read_marks (readable_type, readable_id, reader_type, reader_id, timestamp)
             SELECT readable_type, readable_id, "User", user_id, updated_at
             FROM readings;"
  end
end
