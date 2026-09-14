# frozen_string_literal: true

class AddTechPathLookupIndexToLogLines < ActiveRecord::Migration[8.1]
  def change
    add_index :log_lines, %i[event_type created_at id], name: 'index_log_lines_on_event_type_and_order'
  end
end