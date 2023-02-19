class IncreaseArticleTextLimit < ActiveRecord::Migration[4.2]
  def up
    change_column :articles, :text, :text, :limit => 16777215
    change_column :articles, :text_parsed, :text, :limit => 16777215

    change_column :article_versions, :text, :text, :limit => 16777215
    change_column :article_versions, :text_parsed, :text, :limit => 16777215
  end

  def down
    change_column :articles, :text, :text, :limit => 65535
    change_column :articles, :text_parsed, :text, :limit => 65535

    change_column :article_versions, :text, :text, :limit => 65535
    change_column :article_versions, :text_parsed, :text, :limit => 65535
  end
end
