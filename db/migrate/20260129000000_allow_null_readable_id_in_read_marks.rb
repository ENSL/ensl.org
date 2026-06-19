# frozen_string_literal: true

class AllowNullReadableIdInReadMarks < ActiveRecord::Migration[6.0]
  def change
    change_column_null :read_marks, :readable_id, true
  end
end
