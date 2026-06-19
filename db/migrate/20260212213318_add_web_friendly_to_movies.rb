# frozen_string_literal: true

class AddWebFriendlyToMovies < ActiveRecord::Migration[8.1]
  def change
    add_column :movies, :web_friendly, :boolean, default: false, null: false
  end
end
