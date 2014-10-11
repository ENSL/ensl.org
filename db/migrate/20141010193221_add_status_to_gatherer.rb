class AddStatusToGatherer < ActiveRecord::Migration
  def change
		add_column :gatherers, :status, :int, null: false, default: 0
  end
end
