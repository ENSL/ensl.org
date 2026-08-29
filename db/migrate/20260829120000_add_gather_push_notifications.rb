# frozen_string_literal: true

class AddGatherPushNotifications < ActiveRecord::Migration[8.1]
  def change
    add_column :profiles, :notify_push_gather, :boolean, null: false, default: false

    create_table :push_subscriptions, id: :integer do |t|
      t.integer :user_id, null: false
      t.string :endpoint, null: false, limit: 500
      t.string :p256dh_key, null: false, limit: 255
      t.string :auth_key, null: false, limit: 255
      t.string :user_agent, limit: 255
      t.datetime :created_at, precision: nil
      t.datetime :updated_at, precision: nil
    end

    add_index :push_subscriptions, :user_id
    # MySQL caps unique index keys, so only the leading part of the endpoint is indexed.
    add_index :push_subscriptions, :endpoint, unique: true, length: 191
  end
end
