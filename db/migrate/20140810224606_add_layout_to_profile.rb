class AddLayoutToProfile < ActiveRecord::Migration[4.2]
  def change
    add_column :profiles, :layout, :string
  end
end
