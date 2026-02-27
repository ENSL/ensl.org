# frozen_string_literal: true

class AddStatusToServerVersions < ActiveRecord::Migration[8.1]
  def change
    add_column :server_versions, :status, :string, default: 'offline', null: false
  end
end
