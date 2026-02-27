# frozen_string_literal: true

class RemoveIrcAndAddStatusToServers < ActiveRecord::Migration[8.1]
  def change
    remove_column :servers, :irc, :string
    add_column :servers, :status, :string, default: 'offline', null: false
  end
end
