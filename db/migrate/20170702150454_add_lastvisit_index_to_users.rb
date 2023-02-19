class AddLastvisitIndexToUsers < ActiveRecord::Migration[4.2]
  def change
    add_index :users, :lastvisit
  end
end
