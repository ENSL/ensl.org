class BigSession < ActiveRecord::Migration
  def up
    change_table :sessions do |t|
      t.change :data, :longtext
    end
  end

  def down
  end
end
