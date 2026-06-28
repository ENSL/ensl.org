class AddUniqueIndexesForUniquenessValidations < ActiveRecord::Migration[7.0]
  def up
    cleanup_duplicate_rows!

    # contester: team_id uniqueness scoped to contest_id
    unless index_exists?(:contesters, %i[team_id contest_id], unique: true)
      add_index :contesters, %i[team_id contest_id], unique: true,
                name: 'index_contesters_on_team_id_and_contest_id_unique'
    end

    # forumer: group_id uniqueness scoped to forum_id and access
    unless index_exists?(:forumers, %i[group_id forum_id access], unique: true)
      add_index :forumers, %i[group_id forum_id access], unique: true,
                name: 'index_forumers_on_group_id_forum_id_access_unique'
    end

    # gatherer: user_id uniqueness scoped to gather_id
    unless index_exists?(:gatherers, %i[user_id gather_id], unique: true)
      add_index :gatherers, %i[user_id gather_id], unique: true,
                name: 'index_gatherers_on_user_id_and_gather_id_unique'
    end

    # grouper: user_id uniqueness scoped to group_id
    unless index_exists?(:groupers, %i[user_id group_id], unique: true)
      add_index :groupers, %i[user_id group_id], unique: true,
                name: 'index_groupers_on_user_id_and_group_id_unique'
    end

    # prediction: match_id uniqueness scoped to user_id
    unless index_exists?(:predictions, %i[match_id user_id], unique: true)
      add_index :predictions, %i[match_id user_id], unique: true,
                name: 'index_predictions_on_match_id_and_user_id_unique'
    end

    # vote: user_id uniqueness scoped to votable_id and votable_type
    unless index_exists?(:votes, %i[user_id votable_id votable_type], unique: true)
      add_index :votes, %i[user_id votable_id votable_type], unique: true,
                name: 'index_votes_on_user_id_votable_unique'
    end

    # custom_url: name should be unique
    unless index_exists?(:custom_urls, :name, unique: true)
      remove_index :custom_urls, :name, if_exists: true
      add_index :custom_urls, :name, unique: true
    end
  end

  def down
    remove_index :contesters, name: 'index_contesters_on_team_id_and_contest_id_unique', if_exists: true
    remove_index :forumers, name: 'index_forumers_on_group_id_forum_id_access_unique', if_exists: true
    remove_index :gatherers, name: 'index_gatherers_on_user_id_and_gather_id_unique', if_exists: true
    remove_index :groupers, name: 'index_groupers_on_user_id_and_group_id_unique', if_exists: true
    remove_index :predictions, name: 'index_predictions_on_match_id_and_user_id_unique', if_exists: true
    remove_index :votes, name: 'index_votes_on_user_id_votable_unique', if_exists: true
    remove_index :custom_urls, column: :name, if_exists: true
  end

  private

  def cleanup_duplicate_rows!
    dedupe_by_keys!(:contesters, %w[team_id contest_id])
    dedupe_by_keys!(:forumers, %w[group_id forum_id access])
    dedupe_by_keys!(:gatherers, %w[user_id gather_id])
    dedupe_by_keys!(:groupers, %w[user_id group_id])
    dedupe_by_keys!(:predictions, %w[match_id user_id])
    dedupe_by_keys!(:votes, %w[user_id votable_id votable_type])
  end

  def dedupe_by_keys!(table, columns)
    quoted_table = quote_table_name(table)
    join_conditions = columns.map { |col| "a.#{quote_column_name(col)} <=> b.#{quote_column_name(col)}" }.join(' AND ')

    say_with_time("Deduplicating #{table} by #{columns.join(', ')}") do
      execute <<~SQL.squish
        DELETE a
        FROM #{quoted_table} a
        INNER JOIN #{quoted_table} b
          ON #{join_conditions}
         AND a.id > b.id
      SQL
    end
  end
end
