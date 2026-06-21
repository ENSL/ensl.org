# frozen_string_literal: true

class AddMissingIndexesForBestPractices < ActiveRecord::Migration[8.1]
  def change
    add_index :bracketers, :bracket_id, if_not_exists: true

    add_index :gather_servers, :gather_id, if_not_exists: true
    add_index :gather_servers, :server_id, if_not_exists: true

    add_index :gathers, :category_id, if_not_exists: true

    add_index :gathers_users, :gather_id, if_not_exists: true
    add_index :gathers_users, :user_id, if_not_exists: true

    add_index :groups_users, :group_id, if_not_exists: true
    add_index :groups_users, :user_id, if_not_exists: true

    add_index :maps, :category_id, if_not_exists: true

    add_index :match_proposals, :match_id, if_not_exists: true
    add_index :match_proposals, :team_id, if_not_exists: true

    add_index :matches, :caster_id, if_not_exists: true

    add_index :movies, :category_id, if_not_exists: true

    add_index :ratings, :user_id, if_not_exists: true

    add_index :server_versions, :category_id, if_not_exists: true

    add_index :servers, :category_id, if_not_exists: true
    add_index :servers, %i[recordable_id recordable_type], if_not_exists: true

    add_index :votes, :poll_id, if_not_exists: true
  end
end
