# frozen_string_literal: true

class AddMovieMetadataToMovies < ActiveRecord::Migration[8.1]
  def change
    add_column :movies, :metadata, :json
  end
end
