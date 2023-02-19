class AddPasswordHashToUsers < ActiveRecord::Migration[4.2][6.0]
  def change
    change_table :users do |u|
      u.integer :password_hash, default: User::PASSWORD_MD5
    end
  end
end
