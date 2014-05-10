class AddStream < ActiveRecord::Migration
  def change
    change_table :profiles do |p|
      p.string :stream
    end
  end
end
