class AddLayoutToProfile < ActiveRecord::Migration
  def change
    add_column :profiles, :layout, :string
  end
end
