class AddStatusToGatherer < ActiveRecord::Migration[4.2]
  def change
    add_column :gatherers, :status, :integer, null: false, default: 0
  end
end
