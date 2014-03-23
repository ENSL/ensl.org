class AddNs2 < ActiveRecord::Migration
  def up
    change_table :gathers do |t|
      t.references :category
    end
  end

  def down
  end
end
