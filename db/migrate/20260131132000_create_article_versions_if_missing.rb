class CreateArticleVersionsIfMissing < ActiveRecord::Migration[8.1]
  def up
    return if table_exists?(:article_versions)

    create_table :article_versions do |t|
      t.integer  :article_id
      t.integer  :version
      t.string   :title
      t.text     :text
      t.datetime :created_at
      t.datetime :updated_at
      t.text     :text_parsed
      t.integer  :text_coding, default: 0, null: false
    end

    add_index :article_versions, :article_id, name: 'index_article_versions_on_article_id'
  end

  def down
    drop_table :article_versions if table_exists?(:article_versions)
  end
end
