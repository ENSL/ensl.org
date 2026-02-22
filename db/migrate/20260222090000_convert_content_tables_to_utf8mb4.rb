class ConvertContentTablesToUtf8mb4 < ActiveRecord::Migration[8.1]
  CONTENT_TABLES = %w[
    shoutmsgs
    posts
    comments
    articles
    article_versions
    messages
    issues
    profiles
    topics
  ].freeze

  def up
    CONTENT_TABLES.each do |table_name|
      next unless table_exists?(table_name)

      execute <<~SQL
        ALTER TABLE #{quote_table_name(table_name)}
        CONVERT TO CHARACTER SET utf8mb4
        COLLATE utf8mb4_unicode_ci
      SQL
    end
  end

  def down
    CONTENT_TABLES.each do |table_name|
      next unless table_exists?(table_name)

      execute <<~SQL
        ALTER TABLE #{quote_table_name(table_name)}
        CONVERT TO CHARACTER SET utf8mb3
        COLLATE utf8mb3_general_ci
      SQL
    end
  end
end
