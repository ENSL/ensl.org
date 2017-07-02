class AddLastvisitIndexToUsers < ActiveRecord::Migration
  def change
    add_index :users, :lastvisit
  end
end
