class AddStream < ActiveRecord::Migration[4.2]
  def change
    change_table :profiles do |p|
      p.string :stream
    end
  end
end
