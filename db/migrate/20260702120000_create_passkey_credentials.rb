# frozen_string_literal: true

class CreatePasskeyCredentials < ActiveRecord::Migration[8.1]
  def change
    create_table :passkey_credentials, id: :integer do |t|
      t.integer :user_id, null: false
      t.string :external_id, null: false
      t.text :public_key, size: :medium, null: false
      t.bigint :sign_count, null: false, default: 0
      t.datetime :last_used_at, precision: nil
      t.datetime :created_at, precision: nil
      t.datetime :updated_at, precision: nil
    end

    add_index :passkey_credentials, :user_id
    add_index :passkey_credentials, :external_id, unique: true
  end
end
